#!/usr/bin/env ruby
require 'fileutils'
require 'yaml'

def copy_example_file(example_file)
  if File.exist?(example_file)
    puts "WARNING: You already have the config file #{example_file}, make sure it works with docker"
  else
    puts "Creating config/#{example_file} from config/#{example_file}.example"
    FileUtils.copy_file("#{example_file}.example", example_file)
  end
end

puts "Setting up the database..."
copy_example_file('src/api/config/database.yml')
database_yml = YAML.load_file('src/api/config/database.yml') || {}
database_yml['test']['host'] = 'db'
database_yml['development']['host'] = 'db'
File.open('src/api/config/database.yml', 'w') do |f|
  f.write(YAML.dump(database_yml))
end
%x(docker-compose run --rm frontend rake db:version || docker-compose run --rm frontend rake db:create db:setup db:seed)

puts "Setting up the rails app..."
copy_example_file('src/api/config/options.yml')
options_yml = YAML.load_file('src/api/config/options.yml') || {}
options_yml['source_host'] = 'backend'
options_yml['memcached_host'] = 'cache'
File.open('src/api/config/options.yml', 'w') do |f|
  f.write(YAML.dump(options_yml))
end
%x(docker-compose run --rm frontend bundle exec rails runner '::Configuration.update(enforce_project_keys: true)')
