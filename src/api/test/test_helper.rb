ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

MOCK_BACKEND_DATA_DIR = File.expand_path( RAILS_ROOT+"/test/fixtures/backend" )
MOCK_BACKEND_DATA_TMPDIR= File.expand_path( RAILS_ROOT+"/test/fixtures/backend_tmp" )

class Test::Unit::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  def prepare_request_with_user( request, user, passwd )
    re = 'Basic ' + Base64.encode64( user + ':' + passwd )
    request.env["HTTP_AUTHORIZATION"] = re;
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
      fullpath = @@mock_path_prefix+path
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
      fullpath = @@mock_path_prefix+path
      File.open(fullpath,"w+") do |file|
        file.write data
      end
    end

    def self.logger
      RAILS_DEFAULT_LOGGER
    end
  end

  class Backend
    class << self
      def do_get( host, port, path )
        logger.debug "### mock do_get: "+[host,port,path].join(", ")
        response = MockResponse.new
        response.load(path)
        if response.error?
          raise HTTPError, response
        end
        return response
      end

      def do_put( host, port, path, data )
        logger.debug "### mock do_put: "+[host, port, path, data].join(", ")
        MockWriter.write path, data
        return MockResponse.new 
      end
    end
  end
end
