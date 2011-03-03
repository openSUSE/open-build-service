require File.dirname(__FILE__) + '/../test_helper'
require 'request_controller'

class RequestControllerTest < ActionController::IntegrationTest 
 
  fixtures :all

  def teardown
    prepare_request_with_user "king", "sunflower"
    get "/request"
    dir = ActiveXML::XMLNode.new(@response.body)
    dir.each do |p|
      Suse::Backend.delete "/request/#{p.value(:name)}"
      assert_response :success
    end
  end

  def test_set_and_get_1
    prepare_request_with_user "king", "sunflower"
    # make sure there is at least one
    req = load_backend_file('request/1')
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    id = node.value :id

    put( "/request/#{id}", load_backend_file('request/1'))
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => id} )
    assert_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  def test_get_invalid_1
    prepare_request_with_user "Iggy", "xxx"
    get "/request/0815"
    assert_response 401
  end

  def test_submit_request_with_broken_source
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:Iggy/TestPack?target_project=home:Iggy&target_package=TestPack.DELETE", :cmd => :branch
    assert_response :success
    post "/source/home:Iggy/TestPack.DELETE?target_project=home:Iggy&target_package=TestPack.DELETE2", :cmd => :branch
    assert_response :success
    put "/source/home:Iggy/TestPack.DELETE/conflictingfile", "ASD"
    assert_response :success
    put "/source/home:Iggy/TestPack.DELETE2/conflictingfile", "123"
    assert_response :success

    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_tag( :tag => "summary", :content => 'conflict in file conflictingfile' )
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2" rev="2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_tag( :tag => "summary", :content => 'conflict in file conflictingfile' )

    delete "/source/home:Iggy/TestPack.DELETE"
    assert_response :success
    delete "/source/home:Iggy/TestPack.DELETE2"
    assert_response :success
  end

  def test_submit_broken_request
    prepare_request_with_user "king", "sunflower"
    put "/source/home:coolo:test/kdelibs_DEVEL_package/file", "CONTENT" # just to have a revision, or we fail
    assert_response :success

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/no_such_project')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  
    post "/request?cmd=create", load_backend_file('request/no_such_package')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

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
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )

    post "/request?cmd=create", load_backend_file('request/no_such_target_package')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

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
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

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
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
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

  def test_create_request_review_and_supersede
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
    post "/request/#{id}?cmd=changereviewstate&newstate=superseded&by_user=tom&superseded_by=1"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "superseded", :superseded_by => "1" } )
  end

  def test_create_request_and_supersede
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

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response 403
    assert_tag( :tag => "status", :attributes => { :code => "post_request_no_permission" } )

    # target says supersede it due to another existing request
    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "superseded", :superseded_by => "1" } )
  end

  def test_create_request_and_supersede_as_creator
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

    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :success
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

    # add review not permitted anymore
    post "/request/#{id}?cmd=addreview&by_user=king"
    assert_response 403
    assert_tag( :tag => "status", :attributes => { :code => "add_review_no_permission" } )
  end

  def test_change_review_state_after_leaving_review_phase
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

    # add reviewer group
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "review", :attributes => { :by_group => "test_group" } )

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=tom"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "declined" } )
    assert_tag( :tag => "review", :attributes => { :state => "declined", :by_user => "tom" } )
    assert_tag( :tag => "review", :attributes => { :state => "new", :by_group => "test_group" } )

    # change review not permitted anymore
    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_group=test_group"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "post_request_no_permission" }
  end

  def test_search_and_involved_requests
    prepare_request_with_user "Iggy", "asdfasdf"
    # make sure there is at least one
    req = load_backend_file('request/1')
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body) 
    id = node.value :id

    prepare_request_with_user "king", "sunflower"
    put( "/request/#{id}", load_backend_file('request/1'))
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => id} )
    assert_tag( :tag => "state", :attributes => { :name => 'new' } )

    # via GET
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/request", :match => "(state/@name='new' or state/@name='review') and (action/target/@project='kde4' and action/target/@package='wpa_supplicant')"
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => id} )

    # via POST
    post "/search/request", URI.encode("match=(state/@name='new' or state/@name='review') and (action/target/@project='kde4' and action/target/@package='wpa_supplicant')")
    assert_response :success
    assert_tag( :tag => "request", :attributes => { :id => id} )

    # old style listing
    get "/request"
    assert_response :success
    assert_tag( :tag => 'directory', :child => {:tag => 'entry' } )

    # collection view
    get "/request?view=collection"
    assert_response 404

if $ENABLE_BROKEN_TEST
   #FIXME2.2 there is no code in this test creating request from HiddenProject
    # collection of user involved requests
    get "/request?view=collection&user=Iggy&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_tag( :tag => "source", :attributes => { :project => "HiddenProject", :package => "pack"} )
end

    # collection for given package
    get "/request?view=collection&project=kde4&package=wpa_supplicant&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_tag( :tag => "collection", :attributes => { :matches => "1"} )
    assert_tag( :tag => "target", :attributes => { :project => "kde4", :package => "wpa_supplicant"} )
    assert_tag( :tag => "request", :attributes => { :id => id} )

    # collection for given project
    get "/request?view=collection&project=kde4&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_tag( :tag => "collection", :attributes => { :matches => "1"} )

if $ENABLE_BROKEN_TEST
#FIXME2.2: Either we need to fix complete request controller including search not to show requests with 
#          references or we need to document that requests can tell the existens of projects and packages
# this is working for involved search now, but not for other requests like add_role with a target.
    # tom searches for all request of adrian, but adrian has one in a hidden project which must not be viewable
    prepare_request_with_user "tom", "thunder"
    get "/request?view=collection&user=adrian&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_no_tag( :tag => "target", :attributes => { :project => "HiddenProject"} )

# FIXME: add test cases for group search and for involved project search
end
  end

  def test_submit_request_from_hidden_project_and_hidden_source
    prepare_request_with_user 'tom', 'thunder'
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="HiddenProject" package="pack" rev="1"/>
                                     <target project="home:tom" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 404
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="SourceprotectedProject" package="pack" rev="1"/>
                                     <target project="home:tom" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 403

    prepare_request_with_user "hidden_homer", "homer"
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="HiddenProject" package="pack" rev="1"/>
                                     <target project="kde4" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    prepare_request_with_user "sourceaccess_homer", "homer"
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="SourceprotectedProject" package="pack" rev="1"/>
                                     <target project="kde4" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success
  end

  def test_revoke_when_packages_dont_exist
    prepare_request_with_user 'tom', 'thunder'
    post "/source/kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:tom:branches:kde4" package="kdebase" rev="1"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_tag( :tag => "target", :attributes => { :project => "kde4", :package => "kdebase" } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id1 = node.data['id']

    post "/source/home:tom:branches:kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:tom:branches:home:tom:branches:kde4" package="kdebase" rev="1"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_tag( :tag => "target", :attributes => { :project => "home:tom:branches:kde4", :package => "kdebase" } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id2 = node.data['id']

    # delete projects
    delete "/source/home:tom:branches:kde4"
    assert_response :success
    delete "/source/home:tom:branches:home:tom:branches:kde4"
    assert_response :success

    # test decline and revoke
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response 403
    post "/request/#{id2}?cmd=changestate&newstate=revoked"
    assert_response :success

    # test decline and revoke
    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response :success
  end

  def test_create_and_revoke_submit_request_permissions
    ActionController::IntegrationTest::reset_auth
    req = load_backend_file('request/works')

    post "/request?cmd=create", req
    assert_response 401
    assert_select "status[code] > summary", /Authentication required/

    # create request by non-maintainer => validate created review item
    prepare_request_with_user 'tom', 'thunder'
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    assert_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id_by_package = node.data['id']

    # create request by maintainer
    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/submit_without_target')
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", req
    assert_response 400
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_target_package' } )

    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    assert_no_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # add reviewer
    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=addreview&by_user=adrian"
    assert_response 403
    assert_tag( :tag => "status", :attributes => { :code => 'addreview_not_permitted' } )

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
    post "/request/ILLEGAL_CONTENT?cmd=changestate&newstate=revoked"
    assert_response 404
    assert_match(/Request ID is not a number/, @response.body)

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "revoked" } )

    # decline by_package review
    ActionController::IntegrationTest::reset_auth
    post "/request/#{id_by_package}?cmd=changereviewstate&newstate=declined&by_project=home:Iggy&by_package=TestPack"
    assert_response 401

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id_by_package}?cmd=changereviewstate&newstate=declined&by_project=home:Iggy&by_package=TestPack"
    assert_response 403

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id_by_package}?cmd=changereviewstate&newstate=declined&by_project=home:Iggy&by_package=TestPack"
    assert_response :success

    get "/request/#{id_by_package}"
    assert_response :success
    assert_tag( :tag => "review", :attributes => { :state => "declined", :by_project => "home:Iggy", :by_package => "TestPack", :who => "Iggy" } )
    assert_tag( :tag => "review", :attributes => { :state => "new", :by_user => "adrian" } )
    assert_tag( :tag => "review", :attributes => { :state => "new", :by_group => "test_group" } )
    assert_tag( :tag => "state", :attributes => { :name => "declined" } )

    # reopen with new, but state should become review due to open review
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => "review" } )
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

    # validate our existing test data and fixtures
    get "/source/home:Iggy/ToBeDeletedTestPack/_meta"
    assert_response :success
    get "/source/home:fred:DeleteProject/_meta"
    assert_response :success
    get "/source/kde4/Testing/myfile"
    assert_response 404
    get "/source/kde4/_meta"
    assert_response :success
    assert_no_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_no_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_no_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_no_tag( :tag => "devel", :attributes => { :project => "home:Iggy", :package => "TestPack" } )
    assert_no_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_no_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_no_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )

    # Successful accept the request
    prepare_request_with_user "fred", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    # Validate the executed actions
    get "/source/home:Iggy:branches:kde4/BranchPack/_link"
    assert_response :success
    assert_tag :tag => "link", :attributes => { :project => "kde4", :package => "Testing" }
    get "/source/home:Iggy/ToBeDeletedTestPack"
    assert_response 404
    get "/source/home:fred:DeleteProject"
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

    # cleanup
    prepare_request_with_user "Iggy", "asdfasdf"
    delete "/source/home:Iggy:branches:kde4"
    assert_response :success
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
    assert_match(/Changing review state for request/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 403
    assert_match(/Changing review state for request/, @response.body)
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

    # approve accepted and check initialized devel package
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success
    get "/source/kde4/Testing/_meta"
    assert_response :success
    assert_tag( :tag => "devel", :attributes => { :project => 'home:Iggy', :package => 'TestPack' } )
  end

  def test_branch_and_submit_request_to_linked_project_and_delete_it_again
    prepare_request_with_user "tom", "thunder"

    # branch a package which does not exist in update project, but update project is linked
    post "/source/BaseDistro2/pack2", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack2/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro2:LinkedUpdateProject"
    assert_equal ret.package, "pack2"

    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2:LinkedUpdateProject' package='pack2' rev='1' />
              <options>
                <sourceupdate>cleanup</sourceupdate>
                <updatelink>true</updatelink>
              </options>
            </action>
            <description/>
            <state who='Iggy' name='new'/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # accept the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => 'accepted' } )

    # pack2 got created
    get "/source/BaseDistro2:LinkedUpdateProject/pack2/_link"
    assert_response :success
    assert_tag( :tag => "link", :attributes => { :project => 'BaseDistro2', :package => "pack2" } )

    # create delete request two times
    req = "<request>
            <action type='delete'>
              <target project='BaseDistro2:LinkedUpdateProject' package='pack2'/>
            </action>
            <description/>
            <state who='king' name='new'/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id2 = node.data['id']
    post "/request?cmd=create", req
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id3 = node.data['id']

    # accept the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => 'accepted' } )

    # accept the other request, what will fail
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id2}?cmd=changestate&newstate=accepted"
    assert_response 400
    assert_tag( :tag => "status", :attributes => { :code => 'not_existing_target' } )

    # decline the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id2}?cmd=changestate&newstate=declined"
    assert_response :success
    get "/request/#{id2}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => 'declined' } )
    # do not allow to do it again
    post "/request/#{id2}?cmd=changestate&newstate=declined"
    assert_response 403
    assert_match( /set state to declined from a final state is not allowed./, @response.body )

    # revoke the request
    post "/request/#{id3}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id3}"
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => 'revoked' } )
  end

  # test permissions on read protected objects
  #
  #
  def test_submit_from_source_protected_project
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    post "/request?cmd=create", load_backend_file('request/from_source_protected_valid')
    assert_response :success
    assert_tag( :tag => "request" )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # show diffs
    post "/request/#{id}?cmd=diff", nil
    assert_response :success

    # diffs are secret for others
    ActionController::IntegrationTest::reset_auth
    post "/request/#{id}?cmd=diff", nil
    assert_response 401
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=diff", nil
    assert_response 403
  end

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
    assert_response :success
    #assert_tag( :tag => "state", :attributes => { :name => 'new' } )
  end
  ## create request to hidden package from open place - invalid user - fail 
  # request_controller.rb:178
  def test_create_request_to_hidden_package_from_open_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/to_hidden_from_open_invalid')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  end
  ## create request to hidden package from hidden place - valid user - success
  def test_create_request_to_hidden_package_from_hidden_place_valid_user
    prepare_request_with_user "king", "sunflower"
    put "/source/HiddenProject/target/file", "ASD"
    assert_response :success
    request_hidden("adrian", "so_alone", 'request/to_hidden_from_hidden_valid')
    assert_response :success
    assert_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  ## create request to hidden package from hidden place - invalid user - fail
  def test_create_request_to_hidden_package_from_hidden_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/to_hidden_from_hidden_invalid')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  end

  # requests from Hidden to external
  ## create request from hidden package to open place - valid user  - fail ! ?
  def test_create_request_from_hidden_package_to_open_place_valid_user
    request_hidden("adrian", "so_alone", 'request/from_hidden_to_open_valid')
    # FIXME !!
    # should we really allow this - might be a mistake. qualified procedure could be:
    # sr from hidden to hidden and then make new location visible
    assert_response :success
    # FIXME: implementation unclear
  end
  ## create request from hidden package to open place - invalid user  - fail !
  def test_create_request_from_hidden_package_to_open_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/from_hidden_to_open_invalid')
    assert_response 404
    assert_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  end

  ### bugowner
  ### role 
  def test_hidden_add_role_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/hidden_add_role_fail')
    # should fail as this user shouldn't see the target package at all.
    assert_response 404 if $ENABLE_BROKEN_TEST
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    post "/request?cmd=create", load_backend_file('request/hidden_add_role')
    assert_response :success
  end

  # bugreport bnc #674760
  def test_try_to_delete_project_without_permissions
    prepare_request_with_user "Iggy", "asdfasdf"

    put "/source/home:Iggy:Test/_meta", "<project name='home:Iggy:Test'> <title /> <description /> </project>"
    assert_response :success

    # first action is permitted, but second not
    post "/request?cmd=create", '<request>
                                   <action type="delete">
                                     <target project="home:Iggy:Test"/>
                                   </action>
                                   <action type="delete">
                                     <target project="kde4"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.has_attribute?(:id), true
    id = node.data['id']

    # accept this request without permissions
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response 403

    # everything still there
    get "/source/home:Iggy:Test/_meta"
    assert_response :success
    get "/source/kde4/_meta"
    assert_response :success

    delete "/source/home:Iggy:Test"
    assert_response :success
  end

  def test_special_chars
    prepare_request_with_user "Iggy", "asdfasdf"
    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:Iggy' package='TestPack' />
              <target project='c++' package='TestPack'/>
            </action>
            <description/>
            <state who='Iggy' name='new'/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    
    node = ActiveXML::XMLNode.new(@response.body)
    id = node.value :id
    get "/request/#{id}"    
    assert_response :success
    assert_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

    get "/request?view=collection&user=Iggy&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

    get "/request?view=collection&project=c%2b%2b&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

    get "/request?view=collection&project=c%2b%2b&package=TestPack&state=pending"
    assert_response :success
    assert_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

  end

end

