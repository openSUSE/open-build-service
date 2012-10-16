begin
  require 'active_support'
rescue LoadError
  require 'rubygems'
  gem 'activesupport'
end

require File.join(File.dirname(__FILE__), 'node')
require File.join(File.dirname(__FILE__), 'base')
require File.join(File.dirname(__FILE__), 'transport')
require File.join(File.dirname(__FILE__), 'matcher')
