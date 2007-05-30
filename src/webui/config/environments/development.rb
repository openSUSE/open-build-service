# base settings have moved to development_base.rb

begin
  require 'socket'
  fname = "#{RAILS_ROOT}/config/environments/development.#{Socket.gethostname}.rb"
  eval File.read(fname)
  STDERR.puts "Using local environment #{fname}"
rescue Object
  fname = "#{RAILS_ROOT}/config/environments/development_base.rb"
  eval File.read(fname)
  STDERR.puts "Using global environment #{fname}" 
end
