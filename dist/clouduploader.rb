#!/usr/bin/ruby

require 'fileutils'
require 'json'
require 'ostruct'
require 'open3'

module CloudUploader
  class EC2
    def self.credentials(data)
      # Credentials are stored in  ~/.aws/credentials
      out, err, status = Open3.capture3(
        'aws',
        'sts',
        'assume-role',
        "--role-arn=#{data['arn']}",
        "--external-id=#{data['external_id']}",
        '--role-session-name=obs',
        "--duration-seconds=#{THIRTY_MINUTES}"
      )

      if status.success?
        STDOUT.write("Successfully authenticated.\n")
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

    def self.upload(image, data)
      STDOUT.write("Start uploading image #{image}.\n")

      credentials = credentials(data)

      Open3.popen2e(
        'ec2uploadimg',
        "--description='obs uploader'",
        '--machine=x86_64',
        "--name=#{data['ami_name']}",
        "--region=#{data['region']}",
        "--secret-key=#{credentials.secret_access_key}",
        "--access-id=#{credentials.access_key_id}",
        "--session-token=#{credentials.session_token}",
        '--verbose',
        image
      ) do |_stdin, stdout_stderr, _wait_thr|
        while line = stdout_stderr.gets
          STDOUT.write(line)
        end
        status = wait_thr.value
        abort unless status.success?
      end
    end
  end

  def self.upload(platform, image_path, job_data_file, image_filename)
    STDOUT.sync = true
    start = Time.now

    job_data = JSON.parse(File.read(job_data_file))
    FileUtils.ln_s(image_path, File.join(Dir.pwd, image_filename)) # link file into working directory

    case platform
    when 'ec2'
      THIRTY_MINUTES = 1800
      ENV['PYTHONUNBUFFERED'] = '1'
      CloudUploader::EC2.upload(image_filename, job_data)
    when 'azure'
      # TODO: Add the Azure upload code here
    else
      abort('No valid platform. Valid platforms are ec2 and azure.')
    end

    diff = Time.now - start
    STDOUT.write("Upload took: #{Time.at(diff).utc.strftime("%H:%M:%S")}\n")
  end
end

ENV['HOME'] = '/etc/obs/cloudupload'
raise 'Wrong number of arguments, please provide: user platform upload_file targetdata filename result_path' unless ARGV.length == 6
CloudUploader.upload(*ARGV)
