#!/usr/bin/ruby

require 'fileutils'
require 'json'
require 'ostruct'
require 'open3'
require 'openssl'
require 'base64'

module CloudUploader
  # Module method for uploading the image depending on the platform
  def self.upload(_user, platform, backend_image_file, job_data_file, image_filename, result_path)
    start = Time.now

    $stdout.sync = true
    $stdout.write("Start uploading image #{image_filename}.\n")

    job_data = JSON.parse(File.read(job_data_file))

    case platform
    when 'ec2'
      EC2.new(backend_image_file, image_filename, job_data, result_path).upload
    when 'azure'
      Azure.new(backend_image_file, image_filename, job_data).upload
    else
      abort('No valid platform. Valid platforms are "ec2" and "azure".')
    end

    diff = Time.now - start
    $stdout.write("Upload took: #{Time.at(diff).utc.strftime('%H:%M:%S')}\n")
  end

  class EC2
    THIRTY_MINUTES = 1800

    def initialize(backend_image_file, image_filename, job_data, result_path)
      ENV['HOME'] = '/etc/obs/cloudupload'
      ENV['PYTHONUNBUFFERED'] = '1'
      FileUtils.ln_s(backend_image_file, File.join(Dir.pwd, image_filename))
      @image_filename = image_filename
      @ami_name       = job_data['ami_name']
      @region         = job_data['region']
      @vpc_subnet_id  = job_data['vpc_subnet_id']
      @arn            = job_data['arn']
      @external_id    = job_data['external_id']
      @credentials    = credentials
      @result_path    = result_path
    end

    def upload
      command = [
        'ec2uploadimg',
        "--description='obs uploader'",
        '--machine=x86_64',
        "--name=#{@ami_name}",
        "--region=#{@region}",
        "--secret-key=#{@credentials.secret_access_key}",
        "--access-id=#{@credentials.access_key_id}",
        "--session-token=#{@credentials.session_token}",
        '--verbose'
      ]

      command << "--vpc-subnet-id=#{@vpc_subnet_id}" if @vpc_subnet_id
      command << @image_filename

      Open3.popen2e(*command) do |_stdin, stdout_stderr, wait_thr|
        Signal.trap('TERM') do
          # We just omit the SIGTERM because otherwise we would not get logs from ec2uploadimg
          $stdout.write("Received abort signal, waiting for ec2uploadimg to properly clean up.\n")
        end
        while (line = stdout_stderr.gets)
          $stdout.write(line)
          write_result(Regexp.last_match(1)) if line =~ /^Created\simage:\s+(ami-\w+)$/
        end
        status = wait_thr.value
        abort unless status.success?
      end
    end

    private

    def write_result(result)
      File.write(@result_path, result)
    end

    def credentials
      command = [
        'aws',
        'sts',
        'assume-role',
        "--role-arn=#{@arn}",
        "--external-id=#{@external_id}",
        '--role-session-name=obs',
        "--duration-seconds=#{THIRTY_MINUTES}"
      ]

      # Credentials are stored in  ~/.aws/credentials
      out, err, status = Open3.capture3(*command)

      if status.success?
        $stdout.write("Successfully authenticated.\n")
        json = JSON.parse(out)
        OpenStruct.new(
          access_key_id: json['Credentials']['AccessKeyId'],
          secret_access_key: json['Credentials']['SecretAccessKey'],
          session_token: json['Credentials']['SessionToken']
        )
      else
        abort(err)
      end
    end
  end

  class Azure
    def initialize(backend_image_file, image_filename, job_data)
      ENV['HOME'] = Dir.pwd
      @subscription = job_data['subscription']
      @storage_account = job_data['storage_account']
      @resource_group = job_data['resource_group']
      @container = job_data['container']
      @image_name = job_data['image_name'].to_s
      @image_name = calculate_image_name(image_filename) if @image_name.empty?
      @uncompressed_file = uncompress(backend_image_file)
      @remote_file_name  = File.basename(@uncompressed_file)
      @application_id, @application_key = decrypt([job_data['application_id'], job_data['application_key']])
    end

    def upload
      login
      create_container
      blob_upload
      image_create
      blob_delete
      logout
    end

    private

    def login
      run_command(['az', 'login', '--service-principal', '-u', @application_id, '-p', @application_key, '--tenant', @subscription, '--debug'],
                  'Logging in as OBS app')
    end

    def create_container
      run_command(['az', 'storage', 'container', 'create', '-n', @container, '--account-name', @storage_account, '--debug'],
                  "Creating container at '#{@storage_account}/#{@container}'")
    end

    def blob_upload
      run_command(['az', 'storage', 'blob', 'upload', '--container-name', @container, '--account-name', @storage_account,
                   '-f', @uncompressed_file, '-n', @remote_file_name, '--debug'],
                  "Uploading image file '#{@uncompressed_file}' to a blob")
    end

    def image_create
      result = run_command(['az', 'image', 'create', '--resource-group', @resource_group, '--name', @image_name,
                            '--source', uploaded_image_url, '--os-type', 'Linux', '--debug'],
                           "Creating image '#{@image_name}' out of the blob '#{@remote_file_name}'")
      $stdout.write("#{JSON.parse(result).inspect}\n")
    end

    def blob_delete
      run_command(['az', 'storage', 'blob', 'delete', '--container-name', @container, '--account-name', @storage_account,
                   '-n', @remote_file_name, '--debug'],
                  'Deleting')
    end

    def logout
      run_command(['az', 'logout'], 'Logging out')
    end

    def decrypt(encrypted_data)
      private_key = ::OpenSSL::PKey::RSA.new(File.read('/etc/obs/cloudupload/secret.pem'))
      encrypted_data.map { |encrypted_string| private_key.private_decrypt(::Base64.decode64(encrypted_string)) }
    end

    def uncompress(backend_image_file)
      file_path = File.join(Dir.pwd, File.basename(backend_image_file))
      compressed_file = "#{file_path}.xz"
      uncompressed_file = "#{file_path}.vhd"
      FileUtils.ln_s(backend_image_file, compressed_file)
      run_command("xz -c -d #{compressed_file} > #{uncompressed_file}", "Uncompressing file '#{backend_image_file}'")
      uncompressed_file
    end

    def calculate_image_name(image_filename)
      image_filename.gsub(/\.xz|\.vhdfixed|\.vhd/, '')
    end

    def run_command(command, message)
      $stdout.write("#{message}...")
      out, err, status = Open3.capture3(*command)
      if status.success?
        $stdout.write("[OK]\n")
        out
      else
        $stdout.write("[ERROR]\n\nLogging out\n\n")
        spawn('az logout')
        $stdout.write("---DEBUG INFO----------------------------------------------------\n" \
                      "Running: '#{safe_str(command)}'\n\n" \
                      "#{safe_str(out)}\n" \
                      "---ERROR MESSAGE-------------------------------------------------\n\n")
        abort(safe_str(err))
      end
    end

    def safe_str(str)
      str.to_s.gsub(@application_id, '*************').gsub(@application_key, '*************')
    end

    def uploaded_image_url
      "https://#{@storage_account}.blob.core.windows.net/#{@container}/#{@remote_file_name}"
    end
  end
end

raise 'Wrong number of arguments, please provide: user platform upload_file targetdata filename' unless ARGV.length == 6

CloudUploader.upload(*ARGV)
