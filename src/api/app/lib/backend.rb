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
require 'api_error'
