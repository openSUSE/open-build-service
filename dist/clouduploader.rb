#!/usr/bin/ruby
require 'json'
require 'ostruct'
require 'open3'

start = Time.now
ONE_HOUR = 3600
KEY_NAME = 'obs'.freeze
PRIVATE_KEY = '/etc/clouduploader.pem'.freeze
HOME = '/etc/obs/cloudupload'.freeze
ENV['HOME'] = HOME
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

def get_ec2_credentials(arn, external_id)
  # Credentials are stored in  ~/.aws/credentials
  out, err, status = Open3.capture3(
    'aws',
    'sts',
    'assume-role',
    "--role-arn=#{arn}",
    "--external-id=#{external_id}",
    '--role-session-name=obs',
    "--duration-seconds=#{ONE_HOUR}"
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

def upload_image_to_ec2(image, credentials, region, filename)
  STDOUT.write("Start uploading image #{filename}.\n")
  name = File.basename(filename)

  Open3.popen2e(
    'ec2uploadimg',
    "--description='obs uploader'",
    '--machine=x86_64',
    "--name=#{name}",
    "--region=#{region}",
    "--secret-key=#{credentials.secret_access_key}",
    "--access-id=#{credentials.access_key_id}",
    "--ssh-key-pair=#{KEY_NAME}",
    "--private-key-file=#{PRIVATE_KEY}",
    "--session-token=#{credentials.session_token}",
    "--target-filename=#{filename}",
    '--verbose',
    image
  ) do |_stdin, stdout_stderr, _wait_thr|
    while line = stdout_stderr.gets
      STDOUT.write(line)
    end
  end
end

if platform == 'ec2'
  region = data['region']
  arn = data['arn']
  external_id = data['external_id']

  credentials = get_ec2_credentials(arn, external_id)
  upload_image_to_ec2(image_path, credentials, region, filename)
else
  abort('No valid platform. Valid platforms is ec2.')
end

diff = Time.now - start
STDOUT.write("Upload took: #{Time.at(diff).utc.strftime("%H:%M:%S")}")
