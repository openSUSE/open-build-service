# Adapted from https://gist.github.com/edjames/1663351
require 'fileutils'

namespace :db do
  namespace :data do
    desc 'Dump data into sql script file: filename=[target filename] (default=db/data/OBS_dump'
    task load: :environment do
      start = Time.now

      output = Rails.root.join('db/data/OBS_dump.bak')
      environment = (ENV.include?('RAILS_ENV')) ? (ENV['RAILS_ENV']) : 'development'
      ENV['RAILS_ENV'] = RAILS_ENV = environment

      config   = Rails.configuration.database_configuration
      database = config[Rails.env]['database']
      username = config[Rails.env]['username']
      password = config[Rails.env]['password']
      filename = ENV['FILENAME'] || Rails.root.join('db/data/OBS_dump')
      default_filename = Rails.root.join('db/data/OBS_dump')
      filename ||= default_filename if File.exists?(default_filename)

      remove_tables(filename, output)

      raise 'Please specify a source file (FILENAME=[source.sql])' if filename.blank?

      puts "Connecting to #{environment}..."
      ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)

      puts "Truncating tables..."
      ActiveRecord::Base.connection.execute('show tables').each do |table|
        unless table.to_s == 'schema_migrations'
          puts "   Truncating #{table}"
          ActiveRecord::Base.connection.execute("truncate table #{table.to_s}")
        end
      end

      puts "Importing data from #{filename}..."
      sh "mysql -u#{username} -p#{password} #{database} < #{output}"
      puts "Completed loading #{filename} into #{environment} environment."
      puts "Time: #{Time.now - start} seconds"
    end

    private

    def remove_tables(input, output)
      skip = false

      open(input, 'r') do |f|
        open(output, 'w') do |f2|
          f.each_line do |line|
            if skip
              if line.start_with?("-- Table structure for table")
                skip = false
              end
            else
              f2.write(line)
              if line.start_with?("-- Dumping data for table `cache_lines`") ||
                  line.start_with?("-- Dumping data for table `project_log_entries`")
                skip = true
              end
            end
          end
        end
      end
    end
  end
end
