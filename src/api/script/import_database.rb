#!/usr/bin/env ruby

# This script downloads database dump from a remote server and imports it into your local database.
# It is a script and not a rake task, because downloading from a remote server usually needs
# a private ssh key. As we're using vagrant in development this would mean that we need to
# copy the private key into the vagrant box which we avoid with this script.
require 'yaml'
require 'fileutils'
require 'optparse'
require 'pathname'

TABLES_TO_REMOVE = ['cache_lines', 'project_log_entries'].freeze
@params = {}
@params[:environment] = 'development'
@options_path = ::File.expand_path('../config/options.yml', __dir__)
@database_path = ::File.expand_path('../config/database.yml', __dir__)
@data_path = ::File.expand_path('../db/data', __dir__)

OptionParser.new do |opts|
  opts.banner = 'Usage: import_database.rb [options]'

  opts.on('-a', '--all', 'Download and import the latest dump into development database.') do |v|
    @params[:all] = v
  end

  opts.on('-i', '--import', 'Import the latest dump into development database. You might want to specify the path with --filename.') do |v|
    @params[:import] = v
  end

  opts.on('-l', '--load', 'Download the latest dump into /db/data directory.') do |v|
    @params[:load] = v
  end

  opts.on('-p', '--path [PATH]', 'Specify the filename of the database dump. Default is /db/data/obs_production.sql.') do |v|
    @params[:path] = v
  end

  opts.on('-e', '--environment [PATH]', 'Specify the rails environment. Default is development.') do |v|
    @params[:environment] = v
  end
end.parse!

def init
  unless File.exist?(@options_path) || File.exist?(@database_path)
    abort('Not possible to locate options.yml or database.yml. Please execute this script in your open-build-service directory.')
  end

  # There is only the filename given
  abort('No parameters, use --help') if @params.count == 1

  if @params[:all] && (@params[:import] || @params[:load] || @params[:path])
    abort('The --all parameter is not valid in combination with --import, --load or --filename')
  end

  if @params[:load] &&
     @params[:filename]
    abort('The --filename parameter is not valid in combination with --load')
  end
end

def load_dump
  options = YAML.load_file(@options_path)
  environment = @params[:environment]

  server = options[environment]['backup_server']
  username = options[environment]['backup_user']
  location = options[environment]['backup_location']
  filename = options[environment]['backup_filename']
  port = options[environment]['backup_port']

  if !server || !username || !location || !filename
    abort('Please specify at least backup_server, backup_user, backup_location and backup_filename in your options.yml')
  end

  puts 'Downloading database backup ...'
  `scp -v -P #{port || 22} #{username}@#{server}:#{File.join(location, filename)} #{@data_path}`
end

def import_dump
  config = YAML.load_file(@database_path)
  options = YAML.load_file(@options_path)

  environment = @params[:environment]
  database = config[environment]['database']
  host = config[environment]['host']
  username = config[environment]['username']
  password = config[environment]['password']
  filename = @params[:path] || options[environment]['backup_filename']

  cmds = ["bzcat #{File.join(@data_path, filename)}"]
  unless TABLES_TO_REMOVE.empty?
    cmds << TABLES_TO_REMOVE.map do |table|
      "sed '/-- Dumping data for table `#{table}`/,/-- Table structure for table/{//!d}'"
    end.join(' | ')
  end
  cmds << "mysql -u#{username} -p#{password} -h#{host} #{database}"

  puts "Extracting and importing data from #{filename}..."
  `#{cmds.join(' | ')}`
  puts "Completed loading #{filename}."
end

start = Time.now
init
load_dump if @params[:all] || @params[:load]
import_dump if @params[:all] || @params[:import]
puts "Time: #{Time.now - start}"
