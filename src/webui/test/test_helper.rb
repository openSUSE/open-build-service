ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'action_controller/integration'

module ActionController
  module Integration #:nodoc:
    class Session
      def add_auth(headers)
        headers = Hash.new if headers.nil?
        if !headers.has_key? "AUTHORIZATION" and IntegrationTest.basic_auth
          headers["AUTHORIZATION"] = IntegrationTest.basic_auth
        end
        return headers
      end

      def get(path, parameters = nil, headers = nil)
        process :get, path, parameters, add_auth(headers)
      end
      def post(path, parameters = nil, headers = nil)
        process :post, path, parameters, add_auth(headers)
      end
      def put(path, parameters = nil, headers = nil)
        process :put, path, parameters, add_auth(headers)
      end
      def delete(path, parameters = nil, headers = nil)
        process :delete, path, parameters, add_auth(headers)
      end

    end
  end

  class IntegrationTest

  @@auth = nil

  def self.reset_auth
    @@auth = nil
  end

  def self.basic_auth
    return @@auth
  end

  def prepare_request_with_user( request, user, passwd )
    re = 'Basic ' + Base64.encode64( user + ':' + passwd )
    @@auth = re
  end 
  
  # will provide a user without special permissions
  def prepare_request_valid_user ( request )
    prepare_request_with_user request, 'tom', 'thunder'
  end
  
  def prepare_request_invalid_user( request )
    prepare_request_with_user request, 'tom123', 'thunder123'
  end

  end 
end

module Suse
  class MockResponse 
    
    def initialize(opt={})
      defaults = {:data => "<status code='ok'/>", :content_type => "text/xml"}
      opt = defaults.merge opt

      @data = opt[:data]
      @content_type = opt[:content_type]
    end

    def load(path)
       

      @error = false

      begin
        if File.ftype(fullpath) == "directory"
          fullpath += "/.directory"
        end

        File.open(fullpath, "r") do |file|
          @data = file.readlines.join("\n")
        end

        @content_type = `file -bi #{path}`
      rescue Errno::ENOENT => e
        logger.debug "### error: #{e.class}"
        @data = "<status code='404'><message>Not found</message></status>"
        @content_type = "text/plain"
        @error = true
      end
    end

    def to_s
      return @data
    end

    def bytesize
      return @data.size
    end

    def fetch(field)
      if field.downcase == "content-type"
        return @content_type
      end
    end

    def body
      @data
    end

    def error?
      @error
    end

    def logger
      RAILS_DEFAULT_LOGGER
    end
  end

end

