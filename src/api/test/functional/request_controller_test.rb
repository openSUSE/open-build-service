require File.dirname(__FILE__) + '/../test_helper'
require 'request_controller'

# Re-raise errors caught by the controller.
class RequestController; def rescue_action(e) raise e end; end

class RequestControllerTest < ActionController::IntegrationTest 
  
  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles, :static_permissions, :roles_static_permissions, :project_group_role_relationships

  def setup
    @controller = RequestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
 
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")

    Suse::Backend.put( '/source/home:tscholz/_meta', DbProject.find_by_name('home:tscholz').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_meta', DbPackage.find_by_name('TestPack').to_axml)
    Suse::Backend.put( '/source/kde4/_meta', DbProject.find_by_name('kde4').to_axml)
  end

  def test_get_1
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    # make sure there is at least one
    Suse::Backend.post( '/request/?cmd=create', load_backend_file('request/1'))
    get "/request/1"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => "1"} )
  end

  def test_get_invalid_1
    prepare_request_with_user @request, "tscholz", "xxx"
    get "/request/1"
    assert_response 401
  end

  def test_submit_request
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/no_such_project')
    assert_response 404
    assert_select "status[code] > summary", /Unknown source project home:guest/
  
    post "/request?cmd=create", load_backend_file('request/no_such_package')
    assert_response 404
    assert_select "status[code] > summary", /Unknown source package mypackage in project home:tscholz/
  end

  def test_set_bugowner_request
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner')
    assert_response :success

    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/
  end

  def test_add_role_request
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/add_role')
    assert_response :success

    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/
  end

  def test_create_permissions
    req = load_backend_file('request/works')
    prepare_request_with_user @request, 'tom', 'thunder'
    post "/request?cmd=create", req
    assert_response 403
    assert_select "status[code] > summary", /No permission to create request for package 'TestPack' in project 'home:tscholz'/

    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )

    req = load_backend_file('request/submit_without_target')
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    post "/request?cmd=create", req
    assert_response 400
    assert_select "status[code] > summary", /target project does not exist/
  end

  def teardown
    Suse::Backend.delete( '/source/home:tscholz' )
    Suse::Backend.delete( '/source/kde4' )
  end

end

