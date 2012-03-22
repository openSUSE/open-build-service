path = Rails.root.join("config/options.yml")

begin
  CONFIG = YAML.load_file(path)
rescue Exception => e
  puts "Error while parsing config file #{path}"
  CONFIG = Hash.new
  raise e
end

#puts "Loaded openSUSE buildservice api config from #{path}"
