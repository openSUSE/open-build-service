# Include hook code here
%w{ controller }.each do |code_dir|
  $:.unshift File.join(directory,"app",code_dir)
end

require 'backgroundrb'
#require "backgroundrb_status_controller"
