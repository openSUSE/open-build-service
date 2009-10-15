# base settings have moved to development_base.rb

require 'socket'
local_path = "#{RAILS_ROOT}/config/environments/development.#{Socket.gethostname}.rb"
base_path = "#{RAILS_ROOT}/config/environments/development_base.rb"

begin
  eval File.read(local_path)
  STDERR.puts "Using local development environment #{local_path}"
rescue Object => e
  STDERR.puts "No local development environment found: #{e}"
  STDERR.puts "Using global development environment #{base_path}"
  eval File.read(base_path)
  
end
