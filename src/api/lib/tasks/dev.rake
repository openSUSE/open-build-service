# Everything that needs to be done before you can use this app

require 'fileutils'
require 'yaml'

namespace :dev do
  task :prepare do
    puts 'Setting up the database configuration...'
    copy_example_file('config/database.yml')
    database_yml = YAML.load_file('config/database.yml') || {}
    database_yml['test']['host'] = 'db'
    database_yml['development']['host'] = 'db'
    File.open('config/database.yml', 'w') do |f|
      f.write(YAML.dump(database_yml))
    end

    puts 'Setting up the application configuration...'
    copy_example_file('config/options.yml')
    options_yml = YAML.load_file('config/options.yml') || {}
    options_yml['source_host'] = 'backend'
    options_yml['memcached_host'] = 'cache'
    File.open('config/options.yml', 'w') do |f|
      f.write(YAML.dump(options_yml))
    end
  end

  desc 'Bootstrap the application'
  task bootstrap: [:prepare, :environment] do
    puts 'Creating the database...'
    begin
      Rake::Task['db:version'].invoke
    rescue
      Rake::Task['db:create'].invoke
      Rake::Task['db:setup'].invoke
      Rake::Task['db:seed'].invoke
    end

    if Rails.env.test?
      puts 'Prepare assets'
      Rake::Task['assets:clobber'].invoke
      Rake::Task['assets:precompile'].invoke
    end

    if Rails.env.development?
      # This is needed to make the signer setup
      puts 'Configure default signing'
      Rake::Task['assets:clobber'].invoke
      ::Configuration.update(enforce_project_keys: true)
    end
  end

  desc 'Run all linters we use'
  task :lint do
    Rake::Task['db:structure:verify'].invoke
    Rake::Task['db:structure:verify_no_bigint'].invoke
    Rake::Task['haml_lint'].invoke
    sh 'rubocop -D -F -S --fail-level convention ../..'
    Rake::Task['git_cop'].invoke
    sh 'jshint .'
  end
end

def copy_example_file(example_file)
  if File.exist?(example_file)
    example_file = File.join(File.expand_path(File.dirname(__FILE__) + '../../'), example_file)
    puts "WARNING: You already have the config file #{example_file}, make sure it works with docker"
  else
    puts "Creating config/#{example_file} from config/#{example_file}.example"
    FileUtils.copy_file("#{example_file}.example", example_file)
  end
end
