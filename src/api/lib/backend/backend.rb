require 'benchmark'
require 'api_exception'
require_dependency 'connection'
require_dependency 'connection_helper'
require_dependency 'file'
require_dependency 'logger'
require_dependency 'test'
require_dependency 'test/tasks'
Dir[File.join(__dir__, 'api', '**', '*.rb')].sort.each {|file| require_dependency file }
