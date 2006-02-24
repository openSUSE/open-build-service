ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

class Test::Unit::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false
 
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
