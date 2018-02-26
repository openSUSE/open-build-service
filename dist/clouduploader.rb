#!/usr/bin/ruby
require 'json'
require 'ostruct'
require 'open3'

start = Time.now
THIRTY_MINUTES = 1800
HOME = '/etc/obs/cloudupload'.freeze
ENV['HOME'] = "/etc/obs/cloudupload"
ENV['PYTHONUNBUFFERED'] = '1'
STDOUT.sync = true

if ARGV.length != 5
  raise 'Wrong number of arguments, please provide: user platform upload_file targetdata filename'
end

platform = ARGV[1]
image_path = ARGV[2]
data_path = ARGV[3]
filename = ARGV[4]
data = JSON.parse(File.read(data_path))
jobid = File.basename(image_path, '.file')

# link file into working directory
FileUtils.ln_s(image_path, File.join(Dir.pwd, filename))

def get_ec2_credentials(data)
  command = [
    'aws',
    'sts',
    'assume-role',
    "--role-arn=#{data['arn']}",
    "--external-id=#{data['external_id']}",
    '--role-session-name=obs',
    "--duration-seconds=#{THIRTY_MINUTES}"
  ]

  # Credentials are stored in  ~/.aws/credentials
  out, err, status = Open3.capture3(*command)

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

def upload_image_to_ec2(image, data, jobid)
  STDOUT.write("Start uploading image #{image}.\n")

  credentials = get_ec2_credentials(data)
  command = [
    'ec2uploadimg',
    "--description='obs uploader'",
    '--machine=x86_64',
    "--name=#{data['ami_name']}",
    "--region=#{data['region']}",
    "--secret-key=#{credentials.secret_access_key}",
    "--access-id=#{credentials.access_key_id}",
    "--session-token=#{credentials.session_token}",
    '--verbose'
  ]

  if data['vpc_subnet_id']
    command << "--vpc-subnet-id=#{data['vpc_subnet_id']}"
  end
  command << image

  Open3.popen2e(*command) do |_stdin, stdout_stderr, wait_thr|
    Signal.trap("TERM") {
      # We just omit the SIGTERM because otherwise we would not get logs from ec2uploadimg
      STDOUT.write("Received abort signal, waiting for ec2uploadimg to properly clean up.\n")
    }
    while line = stdout_stderr.gets
      STDOUT.write(line)
      write_result($1, jobid) if line =~ /^Created\simage:\s+(ami-[\w]+)$/
    end
    status = wait_thr.value
    abort unless status.success?
  end
end

def write_result(result, jobid)
  File.open("#{jobid}.result", "w+") { |file| file.write(result) }
end

if platform == 'ec2'
  upload_image_to_ec2(filename, data, jobid)
else
  abort('No valid platform. Valid platforms is ec2.')
end

diff = Time.now - start
STDOUT.write("Upload took: #{Time.at(diff).utc.strftime("%H:%M:%S")}")
