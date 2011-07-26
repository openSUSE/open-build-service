# base settings have moved to development_base.rb

require 'socket'
fname = "#{RAILS_ROOT}/config/environments/development.#{Socket.gethostname}.rb"
if File.exists? fname
  STDERR.puts "Using local environment #{fname}"
else
  fname = "#{RAILS_ROOT}/config/environments/development_base.rb"
  STDERR.puts "Using global environment #{fname} (development.#{Socket.gethostname}.rb not found)"
end
eval File.read(fname)
