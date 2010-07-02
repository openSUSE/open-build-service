require File.dirname(__FILE__) + '/../test_helper'
require 'request_controller'

class RequestControllerTest < ActionController::IntegrationTest 
  
  fixtures :all

  def setup
    @controller = RequestController.new
 
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")

    @controller.start_test_backend
    Suse::Backend.put( '/source/home:tscholz/_meta', DbProject.find_by_name('home:tscholz').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_meta', DbPackage.find_by_name('TestPack').to_axml)
    Suse::Backend.put( '/source/kde4/_meta', DbProject.find_by_name('kde4').to_axml)
  end

  def test_set_and_get_1
    prepare_request_with_user "king", "sunflower"
    # make sure there is at least one
    Suse::Backend.put( '/request/1', load_backend_file('request/1'))
    get "/request/1"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => "1"} )
    assert_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  def test_get_invalid_1
    prepare_request_with_user "tscholz", "xxx"
    get "/request/1"
    assert_response 401
  end

  def test_submit_request
    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/no_such_project')
    assert_response 404
    assert_select "status[code] > summary", /Unknown source project home:guest/
  
    post "/request?cmd=create", load_backend_file('request/no_such_package')
    assert_response 404
    assert_select "status[code] > summary", /Unknown source package mypackage in project home:tscholz/

    post "/request?cmd=create", load_backend_file('request/no_such_user')
    assert_response 404
    assert_select "status[code] > summary", /Unknown person/

    post "/request?cmd=create", load_backend_file('request/no_such_group')
    assert_response 404
    assert_select "status[code] > summary", /Unknown group/

    post "/request?cmd=create", load_backend_file('request/no_such_role')
    assert_response 404
    assert_select "status[code] > summary", /Unknown role/

    post "/request?cmd=create", load_backend_file('request/no_such_target_project')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target project/

    post "/request?cmd=create", load_backend_file('request/no_such_target_package')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package/

    post "/request?cmd=create", load_backend_file('request/missing_role')
    assert_response 404
    assert_select "status[code] > summary", /No role specified/

    post "/request?cmd=create", load_backend_file('request/failing_cleanup_due_devel_package')
    assert_response 400
    assert_select "status[code] > summary", /following packages use this package as devel package:/
  end

  def test_set_bugowner_request
    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner')
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/

    # test direct put
    prepare_request_with_user "tscholz", "asdfasdf"
    put "/request/#{id}", load_backend_file('request/set_bugowner')
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/request/#{id}", load_backend_file('request/set_bugowner')
    assert_response :success
  end

  def test_add_role_request
    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/add_role')
    assert_response :success

    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/
  end

  def test_create_permissions
    req = load_backend_file('request/works')
    prepare_request_with_user 'tom', 'thunder'
    post "/request?cmd=create", req
    assert_response 403
    assert_select "status[code] > summary", /No permission to create request for package 'TestPack' in project 'home:tscholz'/

    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )

    req = load_backend_file('request/submit_without_target')
    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", req
    assert_response 400
    assert_select "status[code] > summary", /target project does not exist/
  end

  def test_submit_with_review
    req = load_backend_file('request/submit_with_review')

    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    assert_tag( :tag => "request", :child => { :tag => 'state' } )
    assert_tag( :tag => "state", :attributes => { :name => 'review' } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # try to break permissions
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_match /Request is in review state./, @response.body
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response 403
    assert_match /No permission to change state of request/, @response.body
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 403
    assert_match /No permission to change state of request/, @response.body
    post "/request/987654321?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 404
    assert_match /No such request/, @response.body

    # approve reviews
    prepare_request_with_user "adrian", "so_alone"
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "request" )
    assert_tag( :tag => "request", :child => { :tag => 'state' } )
    assert_tag( :tag => "state", :attributes => { :name => 'review' } ) #remains in review state
    get "/request/#{id}"

    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "request" )
    assert_tag( :tag => "request", :child => { :tag => 'state' } )
    assert_tag( :tag => "state", :attributes => { :name => 'new' } ) #switch to new after last review
  end

  def teardown
    Suse::Backend.delete( '/source/home:tscholz' )
    Suse::Backend.delete( '/source/kde4' )
  end

end

