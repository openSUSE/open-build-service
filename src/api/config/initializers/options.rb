path = "#{RAILS_ROOT}/config/options.#{Socket.gethostname}.yml"
unless File.exists? path
  path = "#{RAILS_ROOT}/config/options.yml"
end

begin
  CONFIG = YAML.load_file(path)
rescue Exception => e
  puts "Error while parsing config file #{path}"
  CONFIG = Hash.new
  raise e
end

#puts "Loaded openSUSE buildservice api config from #{path}"
