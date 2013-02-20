# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'request_controller'

class RequestControllerTest < ActionController::IntegrationTest 
 
  fixtures :all

  teardown do
    Timecop.return
  end

  def test_set_and_get_1
    prepare_request_with_user "king", "sunflower"
    # make sure there is at least one
    req = load_backend_file('request/1')
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    id = node.value :id

    put( "/request/#{id}", load_backend_file('request/1'))
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "request", :attributes => { :id => id} )
    assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  def test_get_invalid_1
    prepare_request_with_user "Iggy", "xxx"
    get "/request/0815"
    assert_response 401
  end

  def test_create_invalid
    prepare_request_with_user "king", "sunflower"
    post "/request?cmd=create", "GRFZL"
    assert_response 400
  end

  def test_submit_request_of_new_package
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:Iggy/NEW_PACKAGE", :cmd => :branch
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )
    post "/source/home:Iggy/TestPack", :cmd => :branch, :missingok => "true"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_missing' } )
    post "/source/home:Iggy/NEW_PACKAGE", :cmd => :branch, :missingok => "true"
    assert_response :success
    get "/source/home:Iggy:branches:home:Iggy/NEW_PACKAGE/_link"
    assert_response :success
    assert_xml_tag( :tag => "link", :attributes => { :missingok => 'true', :project => 'home:Iggy', :package => nil } )
    put "/source/home:Iggy:branches:home:Iggy/NEW_PACKAGE/new_file", "my content"
    assert_response :success

    # the birthday of J.K.
    Timecop.freeze(2010, 7, 12)
    # submit request
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:Iggy:branches:home:Iggy" package="NEW_PACKAGE"/>
                                   </action>
                                   <description>DESCRIPTION IS HERE</description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert !id.blank?
    create_time = node['state']['when']
    assert_equal '2010-07-12T00:00:00', create_time

    # aka sleep 1
    Timecop.freeze(1)

    # create more history entries decline, reopen and finally accept it
    post "/request/#{id}?cmd=changestate&newstate=declined&comment=notgood"
    assert_response :success
    Timecop.freeze(1) 
    post "/request/#{id}?cmd=changestate&newstate=new&comment=oops"
    assert_response :success
    Timecop.freeze(1)
    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=approved"
    assert_response :success

    # package got created
    get "/source/home:Iggy/NEW_PACKAGE/new_file"
    assert_response :success

    # validate history of new package
    get "/source/home:Iggy/NEW_PACKAGE/_history"
    assert_response :success
    assert_xml_tag :tag => "requestid", :content => id
    assert_xml_tag :tag => "comment", :content => "DESCRIPTION IS HERE"
    assert_xml_tag :tag => "user", :content => "Iggy"

    # validate request
    get "/request/#{id}"
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert_xml_tag(:tag => "acceptinfo", :attributes => { :rev => '1', :srcmd5 => '1ded65e42c0f04bd08075dfd1fd08105', :osrcmd5 => 'd41d8cd98f00b204e9800998ecf8427e' })
    assert_xml_tag(:tag => "state", :attributes => { :name => "accepted", :who => 'Iggy' })
    assert_xml_tag(:tag => "history", :attributes => { :name => "new", :who => 'Iggy' })
    assert_equal({
        "id"=>id, 
        "action"=>{
          "type"=>"submit", 
          "source"=>{"project"=>"home:Iggy:branches:home:Iggy", "package"=>"NEW_PACKAGE"}, 
          "target"=>{"project"=>"home:Iggy", "package"=>"NEW_PACKAGE"}, 
          "options"=>{"sourceupdate"=>"cleanup"}, 
          "acceptinfo"=>{"rev"=>"1", "srcmd5"=>"1ded65e42c0f04bd08075dfd1fd08105", "osrcmd5"=>"d41d8cd98f00b204e9800998ecf8427e"}
        }, 
        "state"=>{"name"=>"accepted", "who"=>"Iggy", "when"=>"2010-07-12T00:00:03", "comment"=>"approved"}, 
        "history"=>[
                    {"name"=>"new", "who"=>"Iggy", "when"=>"2010-07-12T00:00:00"}, 
                    {"name"=>"declined", "who"=>"Iggy", "when"=>"2010-07-12T00:00:01", "comment"=>'notgood'}, 
                    {"name"=>"new", "who"=>"Iggy", "when"=>"2010-07-12T00:00:02", "comment"=>'oops'}
                   ], 
        "description"=>"DESCRIPTION IS HERE"}, node)

    # compare times
    node = ActiveXML::Node.new(@response.body)
    assert((node.state.value('when') > node.each_history.last.value('when')), "Current state is not newer than the former state")
    assert_equal create_time, node.each_history.first.value('when')
    oldhistory=nil
    node.each_history do |h|
      unless h
        assert((h.value('when') > oldhistory.value('when')), "Current history is not newer than the former history")
      end
      oldhistory=h
    end

    # missingok disapeared
    post "/source/home:Iggy:branches:home:Iggy", :cmd => :undelete
    assert_response :success
    get "/source/home:Iggy:branches:home:Iggy/NEW_PACKAGE/_link"
    assert_response :success
    assert_no_xml_tag(:tag => "link", :attributes => { :missingok => 'true' })

    # cleanup
    delete "/source/home:Iggy:branches:home:Iggy"
    assert_response :success
    
    Timecop.return
  end

  def test_submit_request_with_broken_source
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:Iggy/TestPack?target_project=home:Iggy&target_package=TestPack.DELETE", :cmd => :branch
    assert_response :success
    post "/source/home:Iggy/TestPack.DELETE?target_project=home:Iggy&target_package=TestPack.DELETE2", :cmd => :branch
    assert_response :success

    # create working requests
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value('id')

    # create conflicts
    put "/source/home:Iggy/TestPack.DELETE/conflictingfile", "ASD"
    assert_response :success
    put "/source/home:Iggy/TestPack.DELETE2/conflictingfile", "123"
    assert_response :success

    # accepting request fails in a valid way
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id1}?cmd=changestate&newstate=accepted&comment=review1&force=1"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => {:code => 'expand_error'} )

    # new requests are not possible anymore
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => {:code => 'expand_error'} )
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2" rev="2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => {:code => 'expand_error'} )

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
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  
    post "/request?cmd=create", load_backend_file('request/no_such_package')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

    post "/request?cmd=create", load_backend_file('request/no_such_user')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_found' }, child: { content: %r{Couldn.t find User} } )

    post "/request?cmd=create", load_backend_file('request/no_such_group')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_found' }, child: { content: %r{Couldn.t find Group} } )

    post "/request?cmd=create", load_backend_file('request/no_such_role')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_found' }, child: { content: %r{Couldn.t find Role} }  )

    post "/request?cmd=create", load_backend_file('request/no_such_target_project')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )

    post "/request?cmd=create", load_backend_file('request/no_such_target_package')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

    post "/request?cmd=create", load_backend_file('request/missing_role')
    assert_response 404
    assert_select "status[code] > summary", /No role specified/

    post "/request?cmd=create", load_backend_file('request/failing_cleanup_due_devel_package')
    assert_response 400
    assert_select "status[code] > summary", /Package is used by following packages as devel package:/
  end

  def test_set_bugowner_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner')
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value('id')

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/set_bugowner_fail')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

    post "/request?cmd=create", load_backend_file('request/set_bugowner_fail_unknown_user')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_found' } )

    post "/request?cmd=create", load_backend_file('request/set_bugowner_fail_unknown_group')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_found' } )

    # test direct put
    prepare_request_with_user "Iggy", "asdfasdf"
    put "/request/#{id}", load_backend_file('request/set_bugowner')
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/request/#{id}", load_backend_file('request/set_bugowner')
    assert_response :success
  end

  # FIXME: we need a way to test this with api anonymous config and without
  def test_create_request_anonymous
    post "/request?cmd=create", load_backend_file('request/add_role')
    assert_response 401
  end

  def test_add_role_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/add_role')
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value('id')

    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_package' } )

    post "/request?cmd=create", load_backend_file('request/add_role_fail')
    assert_response 404
  end

  def test_create_request_clone_and_superseed_it
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # do the real mbranch for default maintained packages
    reset_auth
    prepare_request_with_user "tom", "thunder"
    post "/source", :cmd => "branch", :request => id
    assert_response :success

    # got the correct package branched ?
    get "/source/home:tom:branches:REQUEST_#{id}"
    assert_response :success
    get "/source/home:tom:branches:REQUEST_#{id}/TestPack.home_Iggy"
    assert_response :success
    get "/source/home:tom:branches:REQUEST_#{id}/TestPack.home_Iggy/_link"
    assert_response :success
    assert_xml_tag( :tag => "link", :attributes => { :project => "home:Iggy", :package => "TestPack" } )
    get "/source/home:tom:branches:REQUEST_#{id}/_attribute/OBS:RequestCloned"
    assert_response :success
    assert_xml_tag( :tag => "attribute", :attributes => { :namespace => "OBS", :name => "RequestCloned" }, 
                :child => { :tag => "value", :content => id } )
  end

  def test_create_request_review_and_supersede
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # add reviewer
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )
    # try update comment
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=tom&comment=blahfasel"
    assert_response 403

    # update comment for real
    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=tom&comment=blahfasel"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :parent => {:tag => "review", :attributes => { :by_user => "tom" }}, :tag => "comment", :content => 'blahfasel' )

    # invalid state
    post "/request/#{id}?cmd=changereviewstate&newstate=INVALID&by_user=tom&comment=blahfasel"
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => "request_not_modifiable" } )

    # superseded review
    post "/request/#{id}?cmd=changereviewstate&newstate=superseded&by_user=tom&superseded_by=1"
    assert_response :success

    # another final state is not allowed
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom&comment=blahfasel"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "post_request_no_permission" } )
    assert_xml_tag( :tag => "summary", :content => "set state to accepted from a final state is not allowed." )

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "superseded", :superseded_by => "1" } )
  end

  def test_create_request_and_supersede
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "post_request_no_permission" } )

    # target says supersede it due to another existing request
    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "superseded", :superseded_by => "1" } )
  end

  def test_create_request_and_supersede_as_creator
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :success
  end

  def test_create_request_and_decline_review
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # add reviewer
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=declined"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "review_not_specified" } )
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=tom"
    assert_response :success
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "review_change_state_no_permission" } )

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "declined" } )

    # add review not permitted anymore
    post "/request/#{id}?cmd=addreview&by_user=king"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "add_review_no_permission" } )
  end

  # MeeGo BOSS: is using multiple reviews by same user for each step
  def test_create_request_and_multiple_reviews
    # the birthday of J.K.
    Timecop.freeze(2010, 7, 12)

    prepare_request_with_user "Iggy", "asdfasdf"
    post("/request?cmd=create", "<request>
                                   <action type='add_role'>
                                     <target project='home:Iggy' package='TestPack' />
                                     <person name='Iggy' role='reviewer' />
                                    </action>
                                  </request>")

    assert_response :success

    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # add reviewer
    prepare_request_with_user "Iggy", "asdfasdf"
    Timecop.freeze(1) # 0:0:1 review added
    post "/request/#{id}?cmd=addreview&by_user=tom&comment=couldyou"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    # accept review
    prepare_request_with_user 'tom', 'thunder'
    Timecop.freeze(1) # 0:0:2 tom accepts review
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom&comment=review1"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )

    # readd reviewer
    prepare_request_with_user "Iggy", "asdfasdf"
    Timecop.freeze(1) # 0:0:3 yet another review for tom
    post "/request/#{id}?cmd=addreview&by_user=tom&comment=overlooked"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    # accept review
    prepare_request_with_user 'tom', 'thunder'
    Timecop.freeze(1) # 0:0:4 yet another review accept by tom
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom&comment=review2"
    assert_response :success


    # check review comments are the same
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :parent => {:tag => "review", :attributes => { :by_user => "tom" }}, :tag => "comment", :content => 'review1' )
    assert_xml_tag( :parent => {:tag => "review", :attributes => { :by_user => "tom" }}, :tag => "comment", :content => 'review2' )

    # reopen a review
    prepare_request_with_user "tom", "thunder"
    Timecop.freeze(1) # 0:0:5 reopened from tom
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=tom&comment=reopen2", nil
    assert_response :success
    get "/request/#{id}"
    assert_response :success

    assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )
    assert_xml_tag( :parent => {:tag => "review", :attributes => { :state => "accepted", :by_user => "tom" }}, :tag => "comment", :content => 'review1' )
    assert_xml_tag( :parent => {:tag => "review", :attributes => { :state => "new", :by_user => "tom" }}, :tag => "comment", :content => 'reopen2' )
    node = Xmlhash.parse(@response.body)
    assert_equal({ "id" => "#{id}",
                   "action"=>
                   {"type"=>"add_role",
                     "target"=>{"project"=>"home:Iggy", "package"=>"TestPack"},
                     "person"=>{"name"=>"Iggy", "role"=>"reviewer"}},
                   "state"=>
                   {"name"=>"review",
                     "who"=>"tom",
                     "when"=>"2010-07-12T00:00:05",
                     "comment"=>"reopen2"},
                   "review"=>
                   [{"state"=>"accepted",
                      "when"=>"2010-07-12T00:00:01",
                      "who"=>"tom",
                      "by_user"=>"tom",
                      "comment"=>"review1"},
                    {"state"=>"new",
                      "when"=>"2010-07-12T00:00:03",
                      "who"=>"tom",
                      "by_user"=>"tom",
                      "comment"=>"reopen2"}],
                   "history"=>
                   [{"name"=>"new", "who"=>"Iggy", "when"=>"2010-07-12T00:00:00"},
                    {"name"=>"review",
                      "who"=>"Iggy",
                      "when"=>"2010-07-12T00:00:01",
                      "comment"=>"couldyou"},
                    {"name"=>"new",
                      "who"=>"tom",
                      "when"=>"2010-07-12T00:00:02",
                      "comment"=>"review1"},
                    {"name"=>"review",
                      "who"=>"Iggy",
                      "when"=>"2010-07-12T00:00:03",
                      "comment"=>'overlooked'},
                    {"name"=>"new",
                      "who"=>"tom",
                      "when"=>"2010-07-12T00:00:04",
                      "comment"=>"review2"}]}, node)

    infos = JSON.parse(BsRequest.find(id).webui_infos.to_json)

    assert_equal({"id" => id.to_i,
                   "description"=>nil,
                   "state"=>"review",
                   "creator"=>"Iggy",
                   "created_at"=>"2010-07-12T00:00:00Z",
                   "is_target_maintainer"=>false,
                   "my_open_reviews"=>
                   [{ "by_user"=>"tom",
                      "when"=>"2010-07-12T00:00:03Z",
                      "who"=>"tom",
                      "state"=>"new"}],
                   "other_open_reviews"=>[],
                   "events"=>
                   [{"who"=>"Iggy",
                      "what"=>"created request",
                      "when"=>"2010-07-12T00:00:00Z",
                      "comment"=>nil},
                    {"who"=>"Iggy",
                      "what"=>"added review",
                      "when"=>"2010-07-12T00:00:01Z",
                      "comment"=>"couldyou"},
                    {"who"=>"tom",
                      "what"=>"accepted review",
                      "when"=>"2010-07-12T00:00:02Z",
                      "comment"=>"review1",
                      "color"=>"green"},
                    {"who"=>"Iggy",
                      "what"=>"added review",
                      "when"=>"2010-07-12T00:00:03Z",
                      "comment"=>"overlooked"},
                    {"who"=>"tom",
                      "what"=>"accepted review",
                      "when"=>"2010-07-12T00:00:04Z",
                      "comment"=>"review2",
                      "color"=>"green"},
                    {"who"=>"tom",
                      "what"=>"reopened review",
                      "when"=>"2010-07-12T00:00:05Z",
                      "comment"=>"reopen2",
                      "color"=>"maroon"}],
                   "actions"=>
                   [{"type"=>"add_role",
                      "tprj"=>"home:Iggy",
                      "tpkg"=>"TestPack",
                      "name"=>"Add Role",
                      "role"=>"reviewer",
                      "user"=>"Iggy"}]}, infos)
  end
  
  def test_change_review_state_after_leaving_review_phase
    req = load_backend_file('request/works')

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # add reviewer
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    # add reviewer group
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_group => "test_group" } )

    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/#{id}?newstate=new&by_group=test_group&cmd=changereviewstate", "adrian is looking"
    post "/request/#{id}?newstate=new&by_group=test_group&cmd=changereviewstate", "adrian does not care"

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=tom"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "declined" } )
    assert_xml_tag( :tag => "review", :attributes => { :state => "declined", :by_user => "tom" } )
    assert_xml_tag( :tag => "review", :attributes => { :state => "new", :by_group => "test_group" },
                    child: { tag: 'comment', content: "adrian does not care" })

    # change review not permitted anymore
    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_group=test_group"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "review_change_state_no_permission" }

    # search this request and verify that all reviews got rendered.
    get "/search/request", :match => "[@id=#{id}]"
    assert_response :success
    get "/search/request", :match => "[review/@by_user='adrian']"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "adrian" } )
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )
    assert_xml_tag( :tag => "review", :attributes => { :by_group => "test_group" } )

  end

  def test_search_and_involved_requests
    prepare_request_with_user "Iggy", "asdfasdf"

    # make sure there is at least one
    req = load_backend_file('request/1')
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::Node.new(@response.body) 
    id = node.value :id

    prepare_request_with_user "king", "sunflower"
    put( "/request/#{id}", load_backend_file('request/1'))
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "request", :attributes => { :id => id} )
    assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )

    # via GET
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/request", :match => "(state/@name='new' or state/@name='review') and (action/target/@project='kde4' and action/target/@package='wpa_supplicant')"
    assert_response :success
    assert_xml_tag( :tag => "request", :attributes => { :id => id} )

    # via POST
    post "/search/request", URI.encode("match=(state/@name='new' or state/@name='review') and (action/target/@project='kde4' and action/target/@package='wpa_supplicant')")
    assert_response :success
    assert_xml_tag( :tag => "request", :attributes => { :id => id} )

    # test "osc rq"
    get "/search/request", :match => "(state/@who='coolo' or history/@who='coolo')"
    assert_response :success
    assert_xml_tag tag: "collection", children: { count: 1 }

    # old style listing
    get "/request"
    assert_response :success
    assert_xml_tag( :tag => 'directory', :child => {:tag => 'entry' } )

    # collection view
    get "/request?view=collection"
    assert_response 404

    # collection of user involved requests
    get "/request?view=collection&user=Iggy&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
if $ENABLE_BROKEN_TEST
    #FIXME there is no code in this test creating request from HiddenProject

    assert_xml_tag( :tag => "source", :attributes => { :project => "HiddenProject", :package => "pack"} )
end

    # collection for given package
    get "/request?view=collection&project=kde4&package=wpa_supplicant&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "collection", :attributes => { :matches => "1"} )
    assert_xml_tag( :tag => "target", :attributes => { :project => "kde4", :package => "wpa_supplicant"} )
    assert_xml_tag( :tag => "request", :attributes => { :id => id} )

    # collection for given project
    get "/request?view=collection&project=kde4&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "collection", :attributes => { :matches => "3"} )

    # tom searches for all request of adrian, but adrian has one in a hidden project which must not be viewable ...
    prepare_request_with_user "tom", "thunder"
    get "/request?view=collection&user=adrian&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_no_xml_tag( :tag => "target", :attributes => { :project => "HiddenProject"} )

if $ENABLE_BROKEN_TEST
    # ... but adrian gets it
    prepare_request_with_user "adrian", "so_alone"
    get "/request?view=collection&user=adrian&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "target", :attributes => { :project => "HiddenProject"} )
end

  end

  def test_process_devel_request
    prepare_request_with_user "king", "sunflower"

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    assert_no_xml_tag :tag => "devel", :attributes => { :project => "BaseDistro", :package => "pack1" }
    oldmeta=@response.body

    rq = '<request>
           <action type="change_devel">
             <source project="BaseDistro" package="pack1"/>
             <target project="home:Iggy" package="TestPack"/>
           </action>
           <state name="new" />
         </request>'

    post "/request?cmd=create", rq
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # and create a delete request
    rq = '<request>
           <action type="delete">
             <target project="BaseDistro" package="pack1"/>
           </action>
           <state name="new" />
         </request>'

    post "/request?cmd=create", rq
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    iddelete = node.value(:id)

    # try to approve change_devel
    prepare_request_with_user "adrian", "so_alone"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response 403

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    assert_xml_tag :tag => "devel", :attributes => { :project => "BaseDistro", :package => "pack1" }

    # try to create delete request
    rq = '<request>
           <action type="delete">
             <target project="BaseDistro" package="pack1"/>
           </action>
           <state name="new" />
         </request>'

    post "/request?cmd=create", rq
    # this used to verify it can't delete devel links, but that was changed
    assert_response :success

    # try to delete package via old request, it should fail
    prepare_request_with_user "king", "sunflower"
    post "/request/#{iddelete}?cmd=changestate&newstate=accepted"
    assert_response 400

    # cleanup
    put "/source/home:Iggy/TestPack/_meta", oldmeta.dup
    assert_response :success

  end

  def test_reject_request_creation
    prepare_request_with_user "Iggy", "asdfasdf"

    # block request creation in project
    post "/source/home:Iggy/_attribute", "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Go Away</value> </attribute> </attributes>"
    assert_response :success

    rq = '<request>
           <action type="submit">
             <source project="BaseDistro" package="pack1" rev="1"/>
             <target project="home:Iggy" package="TestPack"/>
           </action>
           <state name="new" />
         </request>'

    post "/request?cmd=create", rq
    assert_response 403
    assert_match(/Go Away/, @response.body)
    assert_xml_tag :tag => "status", :attributes => { :code => "request_rejected" }

    # just for submit actions
    post "/source/home:Iggy/_attribute", "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>No Submits</value> <value>submit</value> </attribute> </attributes>"
    assert_response :success
    post "/request?cmd=create", rq
    assert_response 403
    assert_match(/No Submits/, @response.body)
    assert_xml_tag :tag => "status", :attributes => { :code => "request_rejected" }
    # but it works when blocking only for others
    post "/source/home:Iggy/_attribute", "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Submits welcome</value> <value>delete</value> <value>set_bugowner</value> </attribute> </attributes>"
    assert_response :success
    post "/request?cmd=create", rq
    assert_response :success


    # block request creation in package
    post "/source/home:Iggy/TestPack/_attribute", "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Package blocked</value> </attribute> </attributes>"
    assert_response :success

    post "/request?cmd=create", rq
    assert_response 403
    assert_match(/Package blocked/, @response.body)
    assert_xml_tag :tag => "status", :attributes => { :code => "request_rejected" }
    # remove project attribute lock
    delete "/source/home:Iggy/_attribute/OBS:RejectRequests"
    assert_response :success
    # still not working
    post "/request?cmd=create", rq
    assert_response 403
    assert_match(/Package blocked/, @response.body)
    assert_xml_tag :tag => "status", :attributes => { :code => "request_rejected" }

    # just for submit actions
    post "/source/home:Iggy/TestPack/_attribute", "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>No Submits</value> <value>submit</value> </attribute> </attributes>"
    assert_response :success
    post "/request?cmd=create", rq
    assert_response 403
    assert_match(/No Submits/, @response.body)
    assert_xml_tag :tag => "status", :attributes => { :code => "request_rejected" }
    # but it works when blocking only for others
    post "/source/home:Iggy/TestPack/_attribute", "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Submits welcome</value> <value>delete</value> <value>set_bugowner</value> </attribute> </attributes>"
    assert_response :success
    post "/request?cmd=create", rq
    assert_response :success

#FIXME: test with request without target

    #cleanup
    delete "/source/home:Iggy/TestPack/_attribute/OBS:RejectRequests"
    assert_response :success
  end

  # osc is still submitting with old style by default
  def test_old_style_submit_request
    prepare_request_with_user "hidden_homer", "homer"
    post "/request?cmd=create", '<request type="submit">
                                   <submit>
                                     <source project="HiddenProject" package="pack" rev="1"/>
                                     <target project="kde4" package="DUMMY"/>
                                   </submit>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    # test that old style request got converted
    get "/request/#{id}"
    assert_response :success
    assert_no_xml_tag :tag => 'submit'
    assert_xml_tag :tag => 'action', :attributes => { :type => 'submit' }
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
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)
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
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success
  end

  def test_auto_revoke_when_source_gets_removed_maintenance_incident
    prepare_request_with_user 'tom', 'thunder'
    post "/source/kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:kde4" package="kdebase" rev="1"/>
                                     <target project="My:Maintenance" releaseproject="BaseDistro3" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value(:id)

    prepare_request_with_user 'king', 'sunflower'
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response :success

    # delete projects
    prepare_request_with_user 'tom', 'thunder'
    delete "/source/home:tom:branches:kde4"
    assert_response :success

    # request got automatically revoked
    get "/request/#{id1}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "revoked" } )

    # test revoke
    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response 403
  end

  def test_auto_revoke_when_source_gets_removed_submit
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
    assert_xml_tag( :tag => "target", :attributes => { :project => "kde4", :package => "kdebase" } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value(:id)

    post "/source/home:tom:branches:kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", '<request>
                                   <action type="submit">
                                     <source project="home:tom:branches:home:tom:branches:kde4" package="kdebase" rev="1"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag( :tag => "target", :attributes => { :project => "home:tom:branches:kde4", :package => "kdebase" } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    #id2 = node.value(:id)

    # delete projects
    delete "/source/home:tom:branches:kde4"
    assert_response :success
    delete "/source/home:tom:branches:home:tom:branches:kde4"
    assert_response :success

    # request got automatically revoked
    get "/request/#{id1}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "revoked" } )

    # test decline and revoke
    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response 403 # set back is not allowed
  end

  def test_revoke_and_decline_when_projects_are_not_existing_anymore
    prepare_request_with_user 'tom', 'thunder'

    # test revoke, the request is part of fixtures
    post "/request/999?cmd=changestate&newstate=revoked"
    assert_response :success
    # missing target project
    post "/request/998?cmd=changestate&newstate=revoked"
    assert_response :success

    # missing source project
    post "/request/997?cmd=changestate&newstate=declined"
    assert_response 403

    prepare_request_with_user 'adrian', 'so_alone'
    post "/request/997?cmd=changestate&newstate=declined"
    assert_response :success
  end

  def test_create_and_revoke_submit_request_permissions
    req = "<request>
             <action type='submit'>
               <source project='home:Iggy' package='TestPack' rev='1' />
               <target project='kde4' package='mypackage' />
             </action>
             <description/>
          </request>"

    post "/request?cmd=create", req
    assert_response 401
    assert_select "status[code] > summary", /Authentication required/

    # create request by non-maintainer => validate created review item
    prepare_request_with_user 'tom', 'thunder'
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id_by_package = node.value(:id)

    # find requests which are not in review
    get "/request?view=collection&user=Iggy&states=new"
    assert_response :success
    assert_no_xml_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )
    # find reviews
    get "/request?view=collection&user=Iggy&states=review&reviewstates=new&roles=reviewer"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )

    # test search via xpath as well
    get "/search/request", :match => "state/@name='review' and review[@by_project='home:Iggy' and @state='new']"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )

    # create request by maintainer
    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/submit_without_target')
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", req
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_target_package' } )

    req = load_backend_file('request/works')
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    assert_no_xml_tag( :tag => "review", :attributes => { :by_project => "home:Iggy", :by_package => "TestPack" } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # add reviewer
    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=addreview&by_user=adrian"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => 'addreview_not_permitted' } )

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "tom" } )

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_group => "test_group" } )

    # test search via xpath as well
    get "search/request", :match => "state/@name='review' and review[@by_group='test_group' and @state='new']"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "review", :attributes => { :by_group => "test_group" } )

    # invalid review, by_project is missing
    post "/request/#{id}?cmd=addreview&by_package=kdelibs"
    assert_response 400

    post "/request/#{id}?cmd=addreview&by_project=kde4&by_package=kdelibs"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "kde4", :by_package => "kdelibs" } )

    post "/request/#{id}?cmd=addreview&by_project=home:tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "home:tom", :by_package => nil } )

    # and revoke it
    reset_auth
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response 401

    prepare_request_with_user 'tom', 'thunder'
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response 403
    post "/request/ILLEGAL_CONTENT?cmd=changestate&newstate=revoked"
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "not_found" }

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "revoked" } )

    # decline by_package review
    reset_auth
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
    assert_xml_tag( :tag => "review", :attributes => { :state => "declined", :by_project => "home:Iggy", :by_package => "TestPack", :who => "Iggy" } )
    assert_xml_tag( :tag => "review", :attributes => { :state => "new", :by_user => "adrian" } )
    assert_xml_tag( :tag => "review", :attributes => { :state => "new", :by_group => "test_group" } )
    assert_xml_tag( :tag => "state", :attributes => { :name => "declined" } )

    # reopen with new, but state should become review due to open review
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )
  end

  def test_submit_cleanup_in_not_writable_source
    prepare_request_with_user "Iggy", "asdfasdf"
    [ 'cleanup', 'update' ].each do |modify|
      req = "<request>
              <action type='submit'>
                <source project='Apache' package='apache2' rev='1' />
                <target project='home:Iggy' package='apache2' />
                <options>
                  <sourceupdate>#{modify}</sourceupdate>
                </options>
              </action>
              <description/>
            </request>"
      post "/request?cmd=create", req
      assert_response 403
      assert_xml_tag( :tag => "status", :attributes => { :code => 'lacking_maintainership' } )
    end

    req = "<request>
            <action type='submit'>
              <source project='Apache' package='apache2' rev='1' />
              <target project='home:Iggy' package='apache2' />
              <options>
                <updatelink>true</updatelink>
              </options>
            </action>
            <description/>
          </request>"
    post "/request?cmd=create", req
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => 'lacking_maintainership' } )
  end

  def test_reopen_a_review_declined_request
    [ 'new', 'review' ].each do |newstate|
      prepare_request_with_user "Iggy", "asdfasdf"
      post "/source/Apache/apache2", :cmd => :branch
      assert_response :success
   
      # do a commit
      put "/source/home:Iggy:branches:Apache/apache2/file", "dummy"
      assert_response :success
   
      req = "<request>
              <action type='submit'>
                <source project='home:Iggy:branches:Apache' package='apache2' rev='1' />
              </action>
              <description/>
            </request>"
      post "/request?cmd=create", req
      assert_response :success
      assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )
      node = ActiveXML::Node.new(@response.body)
      assert node.has_attribute?(:id)
      id = node.value(:id)
   
      # add reviewer
      post "/request/#{id}?cmd=addreview&by_user=fred"
      assert_response :success
      get "/request/#{id}"
      assert_response :success
      assert_xml_tag( :tag => "review", :attributes => { :by_user => "fred" } )
   
      # reviewer declines
      prepare_request_with_user "fred", "geröllheimer"
      post "/request/#{id}?cmd=changereviewstate&by_user=fred&newstate=declined"
      assert_response :success
      get "/request/#{id}"
      assert_response :success
      assert_xml_tag( :tag => "review", :attributes => { :state => "declined", :by_user => "fred" } )
   
      # reopen it again and validate that the request opens the review as well
      prepare_request_with_user "Iggy", "asdfasdf"
      post "/request/#{id}?cmd=changestate&newstate=#{newstate}&comment=But+I+want+it"
      assert_response :success
      get "/request/#{id}"
      assert_response :success
      assert_xml_tag( :tag => "review", :attributes => { :state => "new", :by_user => "fred" } )
      assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )
   
      # cleanup
      delete "/source/home:Iggy:branches:Apache"
      assert_response :success
    end
  end

  def test_reopen_revoked_and_declined_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/Apache/apache2", :cmd => :branch
    assert_response :success

    # do a commit
    put "/source/home:Iggy:branches:Apache/apache2/file", "dummy"
    assert_response :success

    req = "<request>
            <action type='submit'>
              <source project='home:Iggy:branches:Apache' package='apache2' rev='1' />
            </action>
            <description/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # revoke it
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "revoked" } )

    # and reopen it as a non-maintainer is not working
    prepare_request_with_user "adrian", "so_alone"
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response 403
    # and reopen it as a non-source-maintainer is not working
    prepare_request_with_user "fredlibs", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response 403

    # reopen it again
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )

    # target is declining it
    prepare_request_with_user "fred", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=declined"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "declined" } )

    # find it as I am the creator
    get "/request?view=collection&states=declined&roles=creator"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "request", :attributes => { :id => id } )

    # find it as another user
    prepare_request_with_user "adrian", "so_alone"
    get "/request?view=collection&user=Iggy&states=declined&roles=creator"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "request", :attributes => { :id => id } )

    # and reopen it as a non-maintainer is not working
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response 403

    # and reopen it as a different maintainer from target
    prepare_request_with_user "fredlibs", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )
  end

  def test_all_action_types
    req = load_backend_file('request/cover_all_action_types_request')
    prepare_request_with_user "Iggy", "asdfasdf"

    # create kdelibs package
    post "/source/kde4/kdebase", :cmd => :branch
    assert_response :success
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)
    assert_xml_tag( :tag => "review", :attributes => { :by_user => "adrian", :state => "new" } )

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
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )

    # a review has been added because we are not maintainer of current devel package, accept it.
    prepare_request_with_user "king", "sunflower"
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "home:coolo:test", :by_package => "kdelibs_DEVEL_package" } )
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_project=home:coolo:test&by_package=kdelibs_DEVEL_package", nil
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )

    # reopen the review
    prepare_request_with_user "tom", "thunder"
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_project=home:coolo:test&by_package=kdelibs_DEVEL_package", nil
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "review" } )
    # and accept it again
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_project=home:coolo:test&by_package=kdelibs_DEVEL_package", nil
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => "new" } )

    # validate our existing test data and fixtures
    prepare_request_with_user "king", "sunflower"
    get "/source/home:Iggy/ToBeDeletedTestPack/_meta"
    assert_response :success
    get "/source/home:fred:DeleteProject/_meta"
    assert_response :success
    get "/source/kde4/Testing/myfile"
    assert_response 404
    get "/source/kde4/_meta"
    assert_response :success
    assert_no_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_no_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_no_xml_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_no_xml_tag( :tag => "devel", :attributes => { :project => "home:Iggy", :package => "TestPack" } )
    assert_no_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_no_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_no_xml_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )

    # Successful accept the request
    prepare_request_with_user "fred", "geröllheimer"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    # Validate the executed actions
    get "/source/home:Iggy:branches:kde4/BranchPack/_link"
    assert_response :success
    assert_xml_tag :tag => "link", :attributes => { :project => "kde4", :package => "Testing" }
    get "/source/home:Iggy/ToBeDeletedTestPack"
    assert_response 404
    get "/source/home:fred:DeleteProject"
    assert_response 404
    get "/source/kde4/Testing/myfile"
    assert_response :success
    get "/source/kde4/_meta"
    assert_response :success
    assert_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_xml_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_xml_tag( :tag => "devel", :attributes => { :project => "home:Iggy", :package => "TestPack" } )
    assert_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "bugowner" } )
    assert_xml_tag( :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" } )
    assert_xml_tag( :tag => "group", :attributes => { :groupid => "test_group", :role => "reader" } )

    # cleanup
    delete "/source/kde4/Testing"
    assert_response :success
    prepare_request_with_user "Iggy", "asdfasdf"
    delete "/source/home:Iggy:branches:kde4"
    assert_response :success
  end

  def test_submit_with_review
    req = load_backend_file('request/submit_with_review')

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", req
    assert_response :success
    # we upload 2 and 2 default reviewers are added
    assert_xml_tag( children: { only: { tag: "review" }, count: 4 } )
    assert_xml_tag( :tag => "state", :attributes => { :name => 'review' }, :parent => { :tag => "request" } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # test search
    get "/request?view=collection&group=test_group&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )

    # try to break permissions
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_match(/Request is in review state./, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response 403
    assert_match(/review state change is not permitted for/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 403
    assert_match(/review state change for group test_group is not permitted for Iggy/, @response.body)
    post "/request/987654321?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response 404
    assert_match(/Couldn't find BsRequest with id=987654321/, @response.body)

    # Only partly matching by_ arguments
    prepare_request_with_user "adrian", "so_alone"
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&by_group=test_group_b"
    assert_response 403
    assert_match(/review state change for group test_group_b is not permitted for adrian/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&by_project=BaseDistro"
    assert_response 403
    assert_match(/review state change for project BaseDistro is not permitted for adrian/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&by_project=BaseDistro&by_package=pack2"
    assert_response 403
    assert_match(/review state change for package BaseDistro\/pack2 is not permitted for adrian/, @response.body)

    # approve reviews for real
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'review' }, 
                    :parent => { :tag => "request" } ) #remains in review state

    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'new' }, 
                    :parent => { :tag => "request" } ) #switch to new after last review

    # approve accepted and check initialized devel package
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success
    get "/source/kde4/Testing/_meta"
    assert_response :success
    assert_xml_tag( :tag => "devel", :attributes => { :project => 'home:Iggy', :package => 'TestPack' } )
  end

  def test_reviewer_added_when_source_maintainer_is_missing
    # create request
    prepare_request_with_user "tom", "thunder"
    req = "<request>
            <action type='submit'>
              <source project='BaseDistro2.0' package='pack2' rev='1' />
              <target project='home:tom' package='pack2' />
            </action>
            <description>SUBMIT</description>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'review' } )
    assert_xml_tag( :tag => "review", :attributes => { :by_project => "BaseDistro2.0", :by_package => "pack2" } )

    # set project to approve it
    prepare_request_with_user "king", "sunflower"
    post "/source/BaseDistro2.0/_attribute", "<attributes><attribute namespace='OBS' name='ApprovedRequestSource' /></attributes>"
    assert_response :success
 
    # create request again
    prepare_request_with_user "tom", "thunder"
    req = "<request>
            <action type='submit'>
              <source project='BaseDistro2.0' package='pack2' rev='1' />
              <target project='home:tom' package='pack2' />
            </action>
            <description>SUBMIT</description>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )
    assert_no_xml_tag( :tag => "review", :attributes => { :by_project => "BaseDistro2.0", :by_package => "pack2" } )

    # cleanup attribute
    prepare_request_with_user "king", "sunflower"
    delete "/source/BaseDistro2.0/_attribute/OBS:ApprovedRequestSource"
    assert_response :success
  end

  def test_branch_and_submit_request_to_linked_project_and_delete_it_again
    # create ower playground
    prepare_request_with_user "king", "sunflower"
    put "/source/DummY/_meta", "<project name='DummY'><title/><description/><link project='BaseDistro2.0'/></project>"
    assert_response :success

    # branch a package which does not exist in project, but project is linked
    prepare_request_with_user "tom", "thunder"
    post "/source/DummY/pack2", :cmd => :branch
    assert_response :success

    # check source link
    get "/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link"
    assert_response :success
    ret = ActiveXML::Node.new @response.body
    assert_equal ret.project, "BaseDistro2.0:LinkedUpdateProject"
    assert_nil ret.package # same package name

    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' rev='1' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='Iggy' name='new'/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # accept the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'accepted' } )

    get "/source/DummY/pack2/_history"
    assert_response :success
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "comment", :content => "SUBMIT" )
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "requestid", :content => id )

    # pack2 got created
    get "/source/DummY/pack2/_link"
    assert_response :success
    assert_xml_tag( :tag => "link", :attributes => { :project => 'BaseDistro2.0', :package => nil } )

    ### try again with update link
    # do some modification
    put "/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/NEW_FILE", "NEW content"
    assert_response :success
    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' rev='2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>cleanup</sourceupdate>
                <updatelink>true</updatelink>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='Iggy' name='new'/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # ensure that the diff shows the link change
    post "/request/#{id}?cmd=diff&view=xml", nil
    assert_response :success
    assert_xml_tag( :parent => { :tag => "file", :attributes => { :state => "changed" } }, :tag => "old", :attributes => { :name => "_link" } )

    # accept the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success

    # the link in pack2 got changed
    get "/source/DummY/pack2/_link"
    assert_response :success
    assert_xml_tag( :tag => "link", :attributes => { :project => 'BaseDistro2.0:LinkedUpdateProject', :package => nil } )

    # the diff is still working due to acceptinfo
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :parent => { :tag => "action", :attributes => { :type => "submit" } }, :tag => "acceptinfo", :attributes => { :rev => "3" } )
    post "/request/#{id}?cmd=diff", nil
    assert_response :success
    assert_match %{NEW_FILE}, @response.body
    post "/request/#{id}?cmd=diff&view=xml", nil
    assert_response :success
    assert_xml_tag( :parent => { :tag => "file", :attributes => { :state => "added" } }, :tag => "new", :attributes => { :name => "NEW_FILE" } )

    ###
    # create delete request two times
    prepare_request_with_user "tom", "thunder"
    req = "<request>
            <action type='delete'>
              <target project='DummY' package='pack2'/>
            </action>
            <description>DELETE REQUEST</description>
            <state who='king' name='new'/>
          </request>"
    post "/request?cmd=create", req
    # we explicitly decided to ignore the who, so tom will become creator
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id2 = node.value(:id)
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id3 = node.value(:id)

    # accept the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'accepted' } )

    # validate result
    get "/source/DummY/pack2/_meta"
    assert_response :success
    assert_xml_tag( :tag => "package", :attributes => { :project => "BaseDistro2.0", :name => "pack2" } )
    get "/source/DummY/pack2/_history?deleted=1"
    assert_response :success
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "comment", :content => "DELETE REQUEST" )
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "requestid", :content => id )

    # accept the other request, what will fail
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => 'not_existing_target' } )

    # decline the request
    post "/request/#{id2}?cmd=changestate&newstate=declined"
    assert_response :success
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'declined' } )

    # submitter is accepting the decline => revoke
    prepare_request_with_user "tom", "thunder"
    post "/request/#{id2}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'revoked' } )

    # try to decline it again after revoke
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id2}?cmd=changestate&newstate=declined"
    assert_response 403
    assert_match( /set state to declined from a final state is not allowed./, @response.body )

    # revoke the request
    post "/request/#{id3}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id3}"
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'revoked' } )
 
    #cleanup
    delete "/source/DummY"
    assert_response :success
  end

  def test_branch_version_update_and_submit_request_back
    # branch a package which does not exist in project, but project is linked
    prepare_request_with_user "tom", "thunder"
    post "/source/home:Iggy/TestPack", :cmd => :branch
    assert_response :success

    # version update
    spec = File.open("#{Rails.root}/test/fixtures/backend/source/home:Iggy/TestPack/TestPack.spec").read()
    spec.gsub!( /^Version:.*/, "Version: 2.42" )
    spec.gsub!( /^Release:.*/, "Release: 1" )
    Suse::Backend.put("/source/home:tom:branches:home:Iggy/TestPack/TestPack.spec", spec)
    assert_response :success

    get "/source/home:tom:branches:home:Iggy/TestPack?view=info&parse=1"
    assert_response :success
    assert_xml_tag( :tag => "version", :content => "2.42" )
    assert_xml_tag( :tag => "release", :content => "1" )

    get "/source/home:tom:branches:home:Iggy/TestPack?expand=1"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:vrev)
    vrev = node.value(:vrev)

    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:home:Iggy' package='TestPack' />
              <options>
                <sourceupdate>update</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='Iggy' name='new'/>
          </request>"
    post "/request?cmd=create", req
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # accept the request
    prepare_request_with_user "king", "sunflower"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/source/home:Iggy/TestPack?view=info&parse=1"
    assert_response :success
    assert_xml_tag( :tag => "version", :content => "2.42" )
    assert_xml_tag( :tag => "release", :content => "1" )

    # vrev must not get smaller after accept
    get "/source/home:tom:branches:home:Iggy/TestPack?expand=1"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:vrev)
    vrev_after_accept = node.value(:vrev)
    assert vrev <= vrev_after_accept
 
    #cleanup
    delete "/source/home:tom:branches:home:Iggy"
    assert_response :success
    # restore original spec file
    Suse::Backend.put("/source/home:Iggy/TestPack/TestPack.spec", File.open("#{Rails.root}/test/fixtures/backend/source/home:Iggy/TestPack/TestPack.spec").read())
    assert_response :success
  end

  # test permissions on read protected objects
  #
  #
  def test_submit_from_source_protected_project
    prepare_request_with_user "sourceaccess_homer", "homer"
    post "/request?cmd=create", load_backend_file('request/from_source_protected_valid')
    assert_response :success
    assert_xml_tag( :tag => "request" )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value('id')

    # show diffs
    post "/request/#{id}?cmd=diff", nil
    assert_response :success

    # diffs are secret for others
    reset_auth
    post "/request/#{id}?cmd=diff", nil
    assert_response 401
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{id}?cmd=diff", nil
    # make sure to always either show a diff or an error - empty diff is not an option
    assert_response 403
  end

  # create requests to hidden from external
  def request_hidden(user, pass, backend_file)
    reset_auth
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
    #assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )
  end
  ## create request to hidden package from open place - invalid user - fail 
  # request_controller.rb:178
  def test_create_request_to_hidden_package_from_open_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/to_hidden_from_open_invalid')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  end
  ## create request to hidden package from hidden place - valid user - success
  def test_create_request_to_hidden_package_from_hidden_place_valid_user
    prepare_request_with_user "king", "sunflower"
    put "/source/HiddenProject/target/file", "ASD"
    assert_response :success
    request_hidden("adrian", "so_alone", 'request/to_hidden_from_hidden_valid')
    assert_response :success
    assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  ## create request to hidden package from hidden place - invalid user - fail
  def test_create_request_to_hidden_package_from_hidden_place_invalid_user
    request_hidden("Iggy", "asdfasdf", 'request/to_hidden_from_hidden_invalid')
    assert_response 404
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
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
    assert_xml_tag( :tag => "status", :attributes => { :code => 'unknown_project' } )
  end

  ### bugowner
  ### role 
  def test_hidden_add_role_request
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request?cmd=create", load_backend_file('request/hidden_add_role_fail')
    # should fail as this user shouldn't see the target package at all.
    assert_response 404 if $ENABLE_BROKEN_TEST
    reset_auth
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
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value('id')

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
    
    node = ActiveXML::Node.new(@response.body)
    id = node.value :id
    get "/request/#{id}"    
    assert_response :success
    assert_xml_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

    get "/request?view=collection&user=Iggy&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

    get "/request?view=collection&project=c%2b%2b&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

    get "/request?view=collection&project=c%2b%2b&package=TestPack&states=new,review"
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => {:tag => 'request' } )
    assert_xml_tag( :tag => "target", :attributes => { :project => "c++", :package => "TestPack"} )

  end

  def test_project_delete_request_with_pending
    # try to replay rq 74774
    prepare_request_with_user "Iggy", "asdfasdf"
    meta="<project name='home:Iggy:todo'><title></title><description/><repository name='base'>
      <path repository='BaseDistroUpdateProject_repo' project='BaseDistro:Update'/>
        <arch>i586</arch>
        <arch>x86_64</arch>
     </repository>
     </project>"

    put url_for(:controller => :source, :action => :project_meta, :project => "home:Iggy:todo"), meta
    assert_response :success 
 
    meta="<package name='realfun' project='home:Iggy:todo'><title/><description/></package>"
    put url_for(:controller => :source, :action => :package_meta, :project => "home:Iggy:todo", :package => "realfun"), meta
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/home:Iggy:todo/realfun", :cmd => "branch"
    assert_response :success
    
    # verify
    get "/source/home:tom:branches:home:Iggy:todo/realfun/_meta"
    assert_response :success

    # now try to delete the original project
    # and create a delete request
    rq = '<request>
           <action type="delete">
             <target project="home:Iggy:todo"/>
           </action>
           <state name="new" />
         </request>'

    post "/request?cmd=create", rq
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    iddelete = node.value('id')
    
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{iddelete}?cmd=changestate&newstate=accepted"
    assert_response :success

    # cleanup
    delete "/source/home:Iggy:todo"
    assert_response 404 # already removed
    prepare_request_with_user "tom", "thunder"
    delete "/source/home:tom:branches:home:Iggy:todo"
    assert_response :success
  end

  def test_repository_delete_request
    prepare_request_with_user "Iggy", "asdfasdf"
    meta="<project name='home:Iggy:todo'><title></title><description/><repository name='base'>
      <path repository='BaseDistroUpdateProject_repo' project='BaseDistro:Update'/>
        <arch>i586</arch>
        <arch>x86_64</arch>
     </repository>
     </project>"

    put url_for(:controller => :source, :action => :project_meta, :project => "home:Iggy:todo"), meta
    assert_response :success 
 
    meta="<package name='realfun' project='home:Iggy:todo'><title/><description/></package>"
    put url_for(:controller => :source, :action => :package_meta, :project => "home:Iggy:todo", :package => "realfun"), meta
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/home:Iggy:todo/realfun", :cmd => "branch"
    assert_response :success
    
    # verify
    get "/source/home:tom:branches:home:Iggy:todo/realfun/_meta"
    assert_response :success

    # delete repository via request
    rq = '<request>
           <action type="delete">
             <target project="home:Iggy:todo" repository="base"/>
           </action>
           <state name="new" />
         </request>'

    post "/request?cmd=create", rq
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    iddelete = node.value('id')
    post "/request?cmd=create", rq
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    iddelete2 = node.value('id')
    
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{iddelete}?cmd=changestate&newstate=accepted"
    assert_response :success

    # verify
    get "/source/home:Iggy:todo/_meta"
    assert_response :success
    assert_no_xml_tag :tag => 'repository', :attributes => { :name => "base" }
    get "/source/home:tom:branches:home:Iggy:todo/_meta"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'repository', :attributes => { :name => "base" } },
                   :tag => 'path', :attributes => { :project => "deleted", :repository => "deleted" }

    # try again and fail
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/request/#{iddelete2}?cmd=changestate&newstate=accepted"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => 'repository_missing' } )

    # cleanup
    delete "/source/home:Iggy:todo"
    assert_response :success
    prepare_request_with_user "tom", "thunder"
    delete "/source/home:tom:branches:home:Iggy:todo"
    assert_response :success
  end

  def test_delete_request_id

    prepare_request_with_user "Iggy", "asdfasdf"
    req = load_backend_file('request/1')
    post "/request?cmd=create", req
    assert_response :success
    
    node = Xmlhash.parse(@response.body)
    id = node['id']
    get "/request/#{id}"    
    assert_response :success

    # old admins can do that
    delete "/request/#{id}"
    assert_response 403
    assert_xml_tag :tag => 'summary', :content => "Requires admin privileges"

    prepare_request_with_user "king", "sunflower"
    delete "/request/#{id}"
    assert_response :success

    get "/request/#{id}"    
    assert_response 404

  end

end

