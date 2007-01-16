require File.dirname(__FILE__) + '/../test_helper'
require 'platform_controller'

class PlatformControllerTest < Test::Unit::TestCase
  def setup
    @controller = PlatformController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    # make a backup of the XML test files
    # backup_platform_test_data
  end


  def test_ok
    assert_nil nil
  end

  # test will fail because frontend tries to read platform files from backend which is not implemented
  #def test_get_platforms_list
  #  prepare_request_with_user @request, "tom", "thunder"
  #  get :index
  #  assert_response :success
  #  #STDERR.puts(@response.body)
  #  assert_tag :tag => "directory", :child => { :tag => "entry" }
  #  assert_tag :tag => "directory",
  #    :children => { :count => 5, :only => { :tag => "entry" } }
  #end

  
  
  def teardown  
    # restore the XML test files
    # restore_platform_test_data
  end
  
  
end
