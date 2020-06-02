require 'fileutils'
require 'yaml'

desc 'Migrate config/options.yml to new format'
task :migrate_options_yml do
  config = YAML.load_file('config/options.yml')
  if config.is_a?(Hash) && config.key?('default')
    puts 'config/options.yml is already converted. Nothing to do here.'
  else
    FileUtils.cp('config/options.yml', 'config/options.yml.bkp')
    puts "A backup has been created at 'config/options.yml.bkp'."

    # Remove default header
    options_yml = File.read('config/options.yml')
                      .gsub("#\n# This file contains the default configuration of the Open Build Service API.\n#", '')
                      .strip

    puts 'Migrating configuration.'
    File.open('config/options.yml', 'w') do |f|
      f.write("#\n# This file contains the default configuration of the Open Build Service API.\n#\n\n")
      f.write("default: &default\n")
      options_yml.each_line do |line|
        f.write("  #{line}")
      end
      f.write("\n\nproduction:\n  <<: *default\n")
      f.write("test:\n  <<: *default\n")
      f.write("development:\n  <<: *default\n")
    end

    puts 'Done.'
  end
end
