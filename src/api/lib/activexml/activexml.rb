# frozen_string_literal: true

begin
  require 'active_support'
rescue LoadError
  require 'rubygems'
  gem 'activesupport'
end

require_dependency File.join(File.dirname(__FILE__), 'node')
require_dependency File.join(File.dirname(__FILE__), 'transport')
