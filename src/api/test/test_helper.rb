ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'action_controller/integration'
require 'opensuse/backend'

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

  def setup_mock_backend_data
    `cp -r #{MOCK_BACKEND_DATA_DIR} #{MOCK_BACKEND_DATA_TMPDIR}`
  end

  def teardown_mock_backend_data
    `rm -rf #{MOCK_BACKEND_DATA_TMPDIR}`
  end


  def backup_source_test_data ( )
    @test_source_datadir = File.expand_path(File.dirname(__FILE__) + "/../../backend-dummy/data_test/source")
    @test_source_databackupdir = File.expand_path(File.dirname(__FILE__) + "/../../backend-dummy/data_source_test_backup")  
    `rm -rf #{@test_source_databackupdir}`
    `cp -r #{@test_source_datadir} #{@test_source_databackupdir}`
  end

  def restore_source_test_data ()
    `rm -rf #{@test_source_datadir}`
    `cp -r #{@test_source_databackupdir} #{@test_source_datadir}`
  end

  def backup_platform_test_data ( )
    @test_platform_datadir = File.expand_path(File.dirname(__FILE__) + "/../../backend-dummy/data_test/platform")
    @test_platform_databackupdir = File.expand_path(File.dirname(__FILE__) + "/../../backend-dummy/data_platform_test_backup")  
    `rm -rf #{@test_platform_databackupdir}`
    `cp -r #{@test_platform_datadir} #{@test_platform_databackupdir}`
  end

  def restore_platform_test_data ()
    `rm -rf #{@test_platform_datadir}`
    `cp -r #{@test_platform_databackupdir} #{@test_platform_datadir}`
  end

  end 
end

module Suse
  class MockResponse 
    @@mock_path_prefix = MOCK_BACKEND_DATA_TMPDIR 
    
    def initialize(opt={})
      defaults = {:data => "<status code='ok'/>", :content_type => "text/xml"}
      opt = defaults.merge opt

      @data = opt[:data]
      @content_type = opt[:content_type]
    end

    def load(path)
      fullpath = @@mock_path_prefix+path.split(/\?/)[0]

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

  class MockWriter
    @@mock_path_prefix = MOCK_BACKEND_DATA_TMPDIR 
    def self.write(path, data)
      path = path.split(/\?/)[0]
      fullpath = @@mock_path_prefix+path
      FileUtils.mkdir_p(File.dirname(fullpath))
      File.open(fullpath,"w+") do |file|
        file.write data
      end
    end

    def self.delete(path)
      # do not really delete things - if things go wrong,
      # I do not want my ~ gone
      path = @@mock_path_prefix+path
      File.rename(path, path + ".away")
    end

    def self.logger
      RAILS_DEFAULT_LOGGER
    end
  end

  class Backend
      def self.get( path, in_headers={})
        logger.debug "### mock get: #{path}"
        response = MockResponse.new
        response.load(path)
        if response.error?
          raise HTTPError, response
        end
        return response
      end

      def self.put( path, data, in_headers={})
        logger.debug "### mock put: "+[path, data].join(", ")
        MockWriter.write path, data
        return MockResponse.new 
      end

      def self.post( path, data, in_headers={})
        logger.debug "### mock post: "+[path, data].join(", ")
        if path =~ /\/request\?cmd=create/
          return self.get("/request/42", in_headers)
        end
        MockWriter.write path, data
        return MockResponse.new
      end

      def self.delete(path, in_headers={}) 
        logger.debug "### mock delete: "
        MockWriter.delete path
        return MockResponse.new
      end

      class << self
        alias_method :get_source, :get
        alias_method :put_source, :put
      end

  end
end

require 'controllers/application_controller'

class ApplicationController
  def backend_post(path, data )
    Suse::Backend.post(path, data)
  end

  def volley(path)
    send_data(Suse::Backend.get(path))
  end
end
