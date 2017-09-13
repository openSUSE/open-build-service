require 'benchmark'
require 'api_exception'
Dir[File.join(__dir__, '**', '*')].each {|file| require_dependency file }
