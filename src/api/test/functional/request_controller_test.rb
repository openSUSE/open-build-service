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
    Suse::Backend.put( '/source/home:tscholz/TestPack/myfile', "DummyContent")
    Suse::Backend.put( '/source/home:tscholz/ToBeDeletedTestPack/_meta', DbPackage.find_by_name('ToBeDeletedTestPack').to_axml)
    Suse::Backend.put( '/source/home:tscholz:OldProject/_meta', DbProject.find_by_name('home:tscholz:OldProject').to_axml)
    Suse::Backend.put( '/source/kde4/_meta', DbProject.find_by_name('kde4').to_axml)
    Suse::Backend.put( '/source/kde4/kdebase/_meta', DbPackage.find_by_name('kdebase').to_axml)
    Suse::Backend.put( '/source/kde4/kdebase/myfile2', "DummyContent")
    Suse::Backend.post( '/source/kde4/kdebase?cmd=commit', "")

    Suse::Backend.put( '/source/home:tscholz:branches:kde4/_meta', DbProject.find_by_name('home:tscholz:branches:kde4').to_axml)
    Suse::Backend.put( '/source/home:tscholz:branches:kde4/BranchPack/_meta', DbPackage.find_by_name('BranchPack').to_axml)
    Suse::Backend.put( '/source/home:tscholz:branches:kde4/BranchPack/myfile', "DummyContent")
    Suse::Backend.post( '/source/home:tscholz:branches:kde4/BranchPack?cmd=commit', "")
  end

  def teardown
    Suse::Backend.delete( '/source/home:tscholz' )
    Suse::Backend.delete( '/source/kde4' )
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

  def test_submit_broken_request
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

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
  end

  def test_create_and_revoke_submit_request_permissions
    ActionController::IntegrationTest::reset_auth
    req = load_backend_file('request/works')

    post "/request?cmd=create", req
    assert_response 401
    assert_select "status[code] > summary", /Authentication required/

    prepare_request_with_user 'tom', 'thunder'
    post "/request?cmd=create", req
    assert_response 403
    assert_select "status[code] > summary", /No permission to create request for package 'TestPack' in project 'home:tscholz'/

    prepare_request_with_user "tscholz", "asdfasdf"
    req = load_backend_file('request/submit_without_target')
    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request?cmd=create", req
    assert_response 400
    assert_select "status[code] > summary", /target project does not exist/

    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # and revoke it
    ActionController::IntegrationTest::reset_auth
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response 401

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response 403

    prepare_request_with_user "tscholz", "asdfasdf"
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "revoked" } )
  end

  def test_all_action_types
    req = load_backend_file('request/cover_all_action_types_request')

    prepare_request_with_user "tscholz", "asdfasdf"
    # create kdelibs package
    post "/source/kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # do not accept request in review state
    get "/request/#{id}"
    prepare_request_with_user "fred", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_match /Request is in review state/, @response.body

    # approve reviews
    prepare_request_with_user "adrian", "so_alone"
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response :success
    prepare_request_with_user "adrian", "so_alone"
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success

    # Successful accept request
    prepare_request_with_user "fred", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    # Validate the executed actions
    get "/source/home:tscholz:branches:kde4"
    assert_response 404
    get "/source/home:tscholz/ToBeDeletedTestPack"
    assert_response 404
    get "/source/home:tscholz:OldProject"
    assert_response 404
    get "/source/kde4/Testing/myfile"
    assert_response :success
    get "/source/kde4/_meta"
    assert_response :success
    assert_tag( :tag => "person", :attributes => { :userid => "tscholz", :role => "bugowner" } )
    assert_tag( :tag => "person", :attributes => { :userid => "tscholz", :role => "maintainer" } )
    assert_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_tag( :tag => "devel", :attributes => { :project => "home:tscholz", :package => "TestPack" } )
    assert_tag( :tag => "person", :attributes => { :userid => "tscholz", :role => "bugowner" } )
    assert_tag( :tag => "person", :attributes => { :userid => "tscholz", :role => "maintainer" } )
    assert_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
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

end

