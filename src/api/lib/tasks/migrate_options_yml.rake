require 'fileutils'
require 'yaml'

desc 'Migrate config/options.yml to new format'
task :migrate_options_yml do
  options_yml = YAML.load_file('config/options.yml')
  if options_yml.key?('default')
    puts 'config/options.yml is already converted. Nothing to do here.'
  else
    FileUtils.cp('config/options.yml', 'config/options.yml.bkp')
    puts "A backup has been created at 'config/options.yml.bkp'."

    new_options_yml = {}
    new_options_yml['production'] = options_yml

    puts 'Migrating configuration.'
    File.open('config/options.yml', 'w') do |f|
      f.write(YAML.dump(new_options_yml))
    end

    puts 'Done.'
  end
end
