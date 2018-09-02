
# This module wraps the library for accessing to the backend server of the Open Build Service
#
module Backend
  # This module holds all the low level calls for the API with the backend server.
  #
  # Usually those methods receive parameters that are strings and return one string that is the body of the
  # response from the backend server (encoded in UTF-8)
  module Api
  end
end

require 'benchmark'
require 'api_exception'
require_dependency 'connection'
require_dependency 'connection_helper'
require_dependency 'error'
require_dependency 'file'
require_dependency 'logger'
require_dependency 'test'
require_dependency 'test/tasks'
Dir[File.join(__dir__, 'api', '**', '*.rb')].sort.each { |file| require_dependency file }
