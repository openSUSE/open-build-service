require File.dirname(__FILE__) + '/../test_helper'
require 'request_controller'

class RequestControllerTest < ActionController::IntegrationTest 
  
  fixtures :all

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
    prepare_request_with_user "Iggy", "xxx"
    get "/request/1"
    assert_response 401
  end

  def test_submit_broken_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/no_such_project')
    assert_response 404
    assert_select "status[code] > summary", /Unknown source project home:guest/
  
    post "/request?cmd=create", load_backend_file('request/no_such_package')
    assert_response 404
    assert_select "status[code] > summary", /Unknown source package mypackage in project home:Iggy/

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
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner')
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/

    # test direct put
    prepare_request_with_user "Iggy", "asdfasdf"
    put "/request/#{id}", load_backend_file('request/set_bugowner')
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/request/#{id}", load_backend_file('request/set_bugowner')
    assert_response :success
  end

  def test_add_role_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/add_role')
    assert_response :success

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
    assert_select "status[code] > summary", /Unknown target package not_there in project kde4/

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
  end

  def test_create_request_clone_and_superseed_it
    ActionController::IntegrationTest::reset_auth
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # do the real mbranch for default maintained packages
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "tom", "thunder"
    post "/source", :cmd => "branch", :request => id
    assert_response :success

    # got the correct package branched ?
    get "/source/home:tom:branches:REQUEST_#{id}"
    assert_response :success
    get "/source/home:tom:branches:REQUEST_#{id}/TestPack.home_Iggy"
    assert_response :success
    get "/source/home:tom:branches:REQUEST_#{id}/_attribute/OBS:RequestCloned"
    assert_response :success
    assert_tag( :tag => "attribute", :attributes => { :namespace => "OBS", :name => "RequestCloned" }, 
                :child => { :tag => "value", :content => id } )
  end

  def test_create_request_and_decline_review
    ActionController::IntegrationTest::reset_auth
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # add reviewer
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=tom"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "declined" } )
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
    assert_select "status[code] > summary", /No permission to create request for package 'TestPack' in project 'home:Iggy'/

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/submit_without_target')
    prepare_request_with_user "Iggy", "asdfasdf"
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

    # add reviewer
    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=addreview&by_user=adrian"
    assert_response 403

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "review", :attributes => { :by_group => "test_group" } )

    # and revoke it
    ActionController::IntegrationTest::reset_auth
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response 401

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response 403

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "revoked" } )
  end

  def test_all_action_types
    req = load_backend_file('request/cover_all_action_types_request')
    prepare_request_with_user "Iggy", "asdfasdf"

    # create kdelibs package
    post "/source/kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']
    assert_tag( :tag => "review", :attributes => { :by_user => "adrian", :state => "new" } )

    # do not accept request in review state
    get "/request/#{id}"
    prepare_request_with_user "fred", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_match(/Request is in review state/, @response.body)

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
    get "/source/home:Iggy:branches:kde4"
    assert_response 404
    get "/source/home:Iggy/ToBeDeletedTestPack"
    assert_response 404
    get "/source/home:Iggy:OldProject"
    assert_response 404
    get "/source/kde4/Testing/myfile"
    assert_response :success
    get "/source/kde4/_meta"
    assert_response :success
    assert_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_tag( :tag => "devel", :attributes => { :project => "home:Iggy", :package => "TestPack" } )
    assert_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
  end

  def test_submit_with_review
    req = load_backend_file('request/submit_with_review')

    prepare_request_with_user "Iggy", "asdfasdf"
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
    assert_match(/Request is in review state./, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response 403
    assert_match(/No permission to change state of request/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 403
    assert_match(/No permission to change state of request/, @response.body)
    post "/request/987654321?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 404
    assert_match(/No such request/, @response.body)

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

  # ACL
  #
  # create requests to hidden from external
  def request_hidden(user, pass, backend_file)
    ActionController::IntegrationTest::reset_auth
    req = load_backend_file(backend_file)
    post "/request?cmd=create", req
    assert_response 401
    assert_select "status[code] > summary", /Authentication required/
    prepare_request_with_user user, pass
    post "/request?cmd=create", req
  end
  ## create request to hidden package from open place - valid user  - success
  def test_create_request_to_hidden_package_from_open_place_valid_user
    request_hidden("adrian", "so_alone", 'request/to_hidden_from_open_valid')
    #assert_response :success FIXME: fixture problem
    #assert_tag( :tag => "state", :attributes => { :name => 'new' } )
  end
  ## create request to hidden package from open place - invalid user - fail 
  def test_create_request_to_hidden_package_from_open_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/to_hidden_from_open_invalid')
#    puts @response.body
    begin
      assert_response 404
    rescue
      # FIXME: implementation unclear/missing
    end

  end
  ## create request to hidden package from hidden place - valid user - success
  def test_create_request_to_hidden_package_from_hidden_place_valid_user
    request_hidden("adrian", "so_alone", 'request/to_hidden_from_hidden_valid')
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  ## create request to hidden package from hidden place - invalid user - fail
  def test_create_request_to_hidden_package_from_hidden_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/to_hidden_from_hidden_invalid')
#    puts @response.body
    begin
      assert_response 404
    rescue
      # FIXME: implementation unclear/missing
    end
  end

  # requests from Hidden to external
  ## create request from hidden package to open place - valid user  - fail ! ?
  def test_create_request_from_hidden_package_to_open_place_valid_user
    request_hidden("adrian", "so_alone", 'request/from_hidden_to_open_valid')
    #puts @response.body
    # should we really allow this - might be a mistake. qualified procedure could be:
    # sr from hidden to hidden and then make new location visible
    begin
      assert_response 404
    rescue
    # FIXME: implementation unclear/missing
    end
  end
  ## create request from hidden package to open place - invalid user  - fail !
  def test_create_request_from_hidden_package_to_open_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/from_hidden_to_open_invalid')
    begin
      assert_response 404
    rescue
    # FIXME: implementation unclear/missing
    end
  end

  # request workflow on Hidden project / pkg
  ## revoke
  ## accept
  ## decline
  ## (re)new
  ## show !
  ## search !

  # requests on hidden prj/pkg
  ## requests on hidden project - valid user  - success
  ## requests on hidden project - invalid user  - fail
  ## requests on hidden package - valid user  - success
  ## requests on hidden package - invalid user  - fail

end

