require File.dirname(__FILE__) + '/../test_helper'
require 'request_controller'

# Re-raise errors caught by the controller.
class RequestController; def rescue_action(e) raise e end; end

class RequestControllerTest < ActionController::IntegrationTest 
  
  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = RequestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
 
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")
    setup_mock_backend_data
  end

  def test_get_42
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/request/42"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => "42"} )
  end

  def test_get_invalid_42
    prepare_request_with_user @request, "tscholz", "xxx"
    get "/request/42"
    assert_response 401
  end

  def test_get_old_format
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/request/17"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => "17"} )
    assert_tag( :tag => "request", :child => { :tag => "action", :attributes => { :type => "submit" } } )
  end


  def test_submit_request
    req = BsRequest.find(:name => "no_such_project")
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", req.dump_xml
    assert_response 404
    assert_select "status[code] > summary", /Unknown source project home:guest/
  
    req = BsRequest.find(:name => "no_such_package")
    post "/request?cmd=create", req.dump_xml
    assert_response 404
    assert_select "status[code] > summary", /Unknown source package mypackage in project home:tscholz/
  end

  def test_create_permissions
    req = BsRequest.find(:name => "works")
    prepare_request_with_user @request, 'tom', 'thunder'
    post "/request?cmd=create", req.dump_xml
    assert_response 403
    assert_select "status[code] > summary", /No permission to create request for package 'TestPack' in project 'home:tscholz'/

    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", req.dump_xml
    assert_response :success
    # the fake id
    assert_tag( :tag => "request", :attributes => { :id => "42"} )

    req = BsRequest.find(:name => "works_without_target")
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", req.dump_xml
    assert_response :success
    # the fake id
    assert_tag( :tag => "request", :attributes => { :id => "42"} )
  end

  def teardown
    # restore the XML test files
    teardown_mock_backend_data
  end

end

