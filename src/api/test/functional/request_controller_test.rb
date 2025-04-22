# rubocop:disable Metrics/ClassLength
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'request_controller'

class RequestControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
    # FIXME: https://github.com/rails/rails/issues/37270
    (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
    ActiveJob::Base.queue_adapter = :inline
  end

  def test_set_and_get_1
    login_king

    xml = <<~XML
      <request>
        <action type='submit'>
          <source project='home:Iggy' package='TestPack' rev='2'/>
          <target project='kde4' package='wpa_supplicant'/>
        </action>
        <description/>
        <state name='new' who='tom' when='2011-12-02T17:20:42'/>
      </request>
    XML
    post '/request?cmd=create', params: xml
    assert_response :success
    new_request_id = BsRequest.last.number
    assert_select 'request', id: new_request_id do
      assert_select 'action', type: 'submit' do
        assert_select 'source', project: 'home:Iggy', package: 'TestPack', rev: '2'
        assert_select 'target', project: 'kde4', package: 'wpa_supplicant'
      end
      assert_select 'state', name: 'review', who: 'tom' do
        assert_select 'comment'
      end
      assert_select 'review', state: 'new', by_user: 'adrian'
      assert_select 'review', state: 'new', by_group: 'test_group'
      assert_select 'description'
    end

    put("/request/#{new_request_id}", params: xml)
    assert_response :success
    get "/request/#{new_request_id}"
    assert_response :success
    assert_select 'request', id: new_request_id do
      assert_select 'state', name: 'new'
    end
  end

  def test_invalid_command
    post '/request?cmd=INVALID'
    assert_response :unauthorized
    login_king
    post '/request?cmd=INVALID', params: '<request>
                                            <action type="submit">
                                              <source project="project1" package="package1" />
                                              <target project="project2" package="package2" />
                                            </action>
                                            <description>Description</description>
                                          </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_command' })
  end

  def test_get_requests_collection
    login_king
    get '/request', params: { view: 'collection', reviewstates: 'accepted' }
    assert_response :success
    # Should respond with a collection of 9 requests
    assert_select 'collection request', 9
    # Should show all data belonging to each request
    assert_select 'collection', matches: 9 do
      assert_select 'request', id: 1000 do
        assert_select 'action', type: 'submit' do
          assert_select 'source', project: 'Apache', package: 'apache2', rev: '1'
          assert_select 'target', project: 'kde4', package: 'apache2'
        end
        assert_select 'state', name: 'review', who: 'tom', when: '2013-09-09T19:15:16' do
          assert_select 'comment'
        end
        assert_select 'review', state: 'new', by_package: 'apache2', by_project: 'Apache'
        assert_select 'review', state: 'new', by_user: 'adrian'
        assert_select 'review', state: 'new', by_group: 'test_group'
        assert_select 'description', 'want to see their reaction'
      end
    end

    # Narrow search for reviews by user adrian
    get '/request', params: { view: 'collection', reviewstates: 'new', roles: 'reviewer', user: 'adrian' }
    assert_response :success

    # Should respond with a collection of 2 requests
    assert_select 'collection request', 2

    # Request 1000 should have exactly 2 review elements
    assert_select "request[id='1000'] review", 4
    # Request 4 should have exactly 1 review elements
    assert_select "request[id='4'] review", 3

    # Should show all data belonging to each request
    assert_select 'collection', matches: 2 do
      assert_select 'request', id: 1000 do
        assert_select 'action', type: 'submit' do
          assert_select 'source', project: 'Apache', package: 'apache2', rev: '1'
          assert_select 'target', project: 'kde4', package: 'apache2'
        end
        assert_select 'state', name: 'review', who: 'tom', when: '2013-09-09T19:15:16' do
          assert_select 'comment'
        end
        assert_select 'review', state: 'new', by_package: 'apache2', by_project: 'Apache'
        assert_select 'review', state: 'new', by_user: 'adrian'
        assert_select 'review', state: 'new', by_user: 'tom'
        assert_select 'review', state: 'new', by_group: 'test_group'
        assert_select 'description', 'want to see their reaction'
      end
      # Should find requests of groups adrian belongs to
      assert_select 'request', id: 4 do
        assert_select 'review', state: 'new', by_group: 'test_group'
      end
    end
  end

  def test_get_invalid_1
    prepare_request_with_user('Iggy', 'xxx')
    get '/request/0815'
    assert_response :unauthorized
  end

  def test_create_invalid
    login_king
    post '/request?cmd=create', params: 'GRFZL'
    assert_response :bad_request

    reset_auth
    # make sure requests from not valid users do not pass
    req = load_backend_file('request/1')
    post '/request?cmd=create', params: req
    assert_response :unauthorized
  end

  def test_submit_request_of_new_package_with_devel_package
    prepare_request_with_user('Iggy', 'buildservice')

    # we have a devel package definition in source
    get '/source/BaseDistro:Update/pack2/_meta'
    assert_response :success
    assert_xml_tag(tag: 'devel')

    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="NEW_PACKAGE"/>
                                   </action>
                                   <description>Source has a devel package</description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?

    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="RemoteInstance:BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="NEW_PACKAGE2"/>
                                   </action>
                                   <description>Source has a devel package</description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id2 = node['id']
    assert id2.present?

    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=approved&force=1"
    assert_response :success
    assert_equal :accepted, BsRequest.find_by_number(id).state

    # Ensure that requests can't be accepted twice
    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=approved&force=1"
    assert_response :forbidden
    assert_select 'status', code: 'post_request_no_permission' do
      assert_select 'summary', 'change state from an accepted state is not allowed.'
    end

    post "/request/#{id2}?cmd=changestate&newstate=accepted&comment=approved&force=1"
    assert_response :success
    assert_equal :accepted, BsRequest.find_by_number(id2).state

    get '/source/home:Iggy/NEW_PACKAGE/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'devel')
    get '/source/home:Iggy/NEW_PACKAGE2/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'devel')

    login_king
    delete '/source/home:Iggy/NEW_PACKAGE'
    assert_response :success
    delete '/source/home:Iggy/NEW_PACKAGE2'
    assert_response :success
  end

  def test_submit_with_and_without_revision
    prepare_request_with_user('Iggy', 'buildservice')

    # we have a devel package definition in source
    get '/source/BaseDistro:Update/pack2/_meta'
    assert_response :success
    assert_xml_tag(tag: 'devel')

    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="NEW_PACKAGE"/>
                                   </action>
                                   <description>Source has a devel package</description>
                                 </request>'
    assert_response :success
    assert_no_xml_tag(tag: 'source', attributes: { rev: 'd430c2f61e4d8999f9ca6ed6667a104e' })

    attrib_type = AttribType.find_by_namespace_and_name('OBS', 'EnforceRevisionsInRequests')
    attrib = Attrib.create(attrib_type: attrib_type, project: Project.find_by_name('home:Iggy'))

    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="RemoteInstance:BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="NEW_PACKAGE2"/>
                                   </action>
                                   <description>Source has a devel package</description>
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'source', attributes: { rev: 'd430c2f61e4d8999f9ca6ed6667a104e' })

    attrib.delete
  end

  def test_submit_request_of_new_package
    Backend::Test.start(wait_for_scheduler: true)

    prepare_request_with_user('Iggy', 'buildservice')
    post '/source/home:Iggy/NEW_PACKAGE', params: { cmd: :branch }
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_package' })
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, missingok: 'true' }
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'not_missing' })
    post '/source/home:Iggy/NEW_PACKAGE', params: { cmd: :branch, missingok: 'true' }
    assert_response :success
    get '/source/home:Iggy:branches:home:Iggy/NEW_PACKAGE/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { missingok: 'true', project: 'home:Iggy', package: nil })
    put '/source/home:Iggy:branches:home:Iggy/NEW_PACKAGE/new_file', params: 'my content'
    assert_response :success

    # the birthday of J.K.
    travel_to(Date.new(2010, 7, 12))
    # submit request
    post '/request?cmd=create', params: '<request>
                                   <priority>critical</priority>
                                   <action type="submit">
                                     <source project="home:Iggy:branches:home:Iggy" package="NEW_PACKAGE"/>
                                   </action>
                                   <description>DESCRIPTION IS HERE</description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?
    create_time = node['state']['when']
    assert_equal '2010-07-12T00:00:00', create_time

    # aka sleep 1
    travel(1.second)

    # create more history entries prio change, decline, reopen and finally accept it
    post "/request/#{id}?cmd=setpriority&priority=ILLEGAL&comment=dontcare"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'request_save_error' })
    assert_xml_tag(tag: 'summary', content: "Illegal priority 'ILLEGAL'")
    post "/request/#{id}?cmd=setpriority&priority=low&comment=dontcare"
    assert_response :success
    travel(1.second)
    post "/request/#{id}?cmd=changestate&newstate=declined&comment=notgood"
    assert_response :success
    travel(1.second)
    post "/request/#{id}?cmd=changestate&newstate=new&comment=oops"
    assert_response :success
    travel(1.second)
    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=approved"
    assert_response :success
    assert_equal :accepted, BsRequest.find_by_number(id).state
    assert_equal 'approved', BsRequest.find_by_number(id).comment

    # package got created
    get '/source/home:Iggy/NEW_PACKAGE/new_file'
    assert_response :success

    # validate history of new package
    get '/source/home:Iggy/NEW_PACKAGE/_history'
    assert_response :success
    assert_xml_tag tag: 'requestid', content: id
    assert_xml_tag tag: 'comment', content: 'DESCRIPTION IS HERE'
    assert_xml_tag tag: 'user', content: 'Iggy'

    # validate request
    get "/request/#{id}?withhistory=1"
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert_xml_tag(tag: 'acceptinfo', attributes: { rev: '1', srcmd5: '1ded65e42c0f04bd08075dfd1fd08105', osrcmd5: 'd41d8cd98f00b204e9800998ecf8427e' })
    assert_xml_tag(tag: 'state', attributes: { name: 'accepted', who: 'Iggy' })
    assert_xml_tag(tag: 'history', attributes: { who: 'Iggy' })
    assert_equal({
                   'id' => id,
                   'creator' => 'Iggy',
                   'action' => {
                     'type' => 'submit',
                     'source' => { 'project' => 'home:Iggy:branches:home:Iggy', 'package' => 'NEW_PACKAGE' },
                     'target' => { 'project' => 'home:Iggy', 'package' => 'NEW_PACKAGE' },
                     'options' => { 'sourceupdate' => 'cleanup' },
                     'acceptinfo' => { 'rev' => '1', 'srcmd5' => '1ded65e42c0f04bd08075dfd1fd08105', 'osrcmd5' => 'd41d8cd98f00b204e9800998ecf8427e' }
                   },
                   'priority' => 'low',
                   'state' => { 'name' => 'accepted', 'who' => 'Iggy', 'when' => '2010-07-12T00:00:04', 'created' => '2010-07-12T00:00:00', 'comment' => 'approved' },
                   'history' => [
                     { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:00', 'description' => 'Request created', 'comment' => 'DESCRIPTION IS HERE' },
                     { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:01', 'description' => 'Request got a new priority: critical => low', 'comment' => 'dontcare' },
                     { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:02', 'description' => 'Request got declined', 'comment' => 'notgood' },
                     { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:03', 'description' => 'Request got reopened', 'comment' => 'oops' },
                     { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:04', 'description' => 'Request got accepted', 'comment' => 'approved' }
                   ],
                   'description' => 'DESCRIPTION IS HERE'
                 }, node)

    # compare times
    node = Xmlhash.parse(@response.body)
    assert_equal(node.elements('state').first.value('when'), node.elements('history').last.value('when'), 'Current state is has NOT same time as last history item')
    oldhistory = nil
    node.elements('history') do |h|
      assert(h.value('when') > oldhistory.value('when'), 'Current history is not newer than the former history') unless h
      oldhistory = h
    end

    # missingok disapeared
    post '/source/home:Iggy:branches:home:Iggy', params: { cmd: :undelete }
    assert_response :success
    get '/source/home:Iggy:branches:home:Iggy/NEW_PACKAGE/_link'
    assert_response :success
    assert_no_xml_tag(tag: 'link', attributes: { missingok: 'true' })

    # cleanup
    login_king
    delete '/source/home:Iggy:branches:home:Iggy'
    assert_response :success
    delete '/source/home:Iggy/NEW_PACKAGE'
    assert_response :success
  end

  def test_request_autodecline_on_removal
    login_Iggy
    post '/source/home:Iggy/TestPack?target_project=home:Iggy&target_package=TestPack.DELETE', params: { cmd: :branch }
    assert_response :success
    post '/source/home:Iggy/TestPack.DELETE?target_project=home:Iggy&target_package=TestPack.DELETE2', params: { cmd: :branch }
    assert_response :success
    put '/source/home:Iggy/TestPack.DELETE2/file', params: 'some'
    assert_response :success

    # create requests
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id1 = node.value('id')
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE"/>
                                     <target project="home:Iggy" package="TestPack.DELETE2"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id2 = node.value('id')

    delete '/source/home:Iggy/TestPack.DELETE2'
    assert_response :success
    get "/request/#{id1}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })

    delete '/source/home:Iggy/TestPack.DELETE'
    assert_response :success
  end

  def test_submit_request_with_broken_source
    login_Iggy
    post '/source/home:Iggy/TestPack?target_project=home:Iggy&target_package=TestPack.DELETE', params: { cmd: :branch }
    assert_response :success
    post '/source/home:Iggy/TestPack.DELETE?target_project=home:Iggy&target_package=TestPack.DELETE2', params: { cmd: :branch }
    assert_response :success

    # create working requests
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id1 = node.value('id')

    # create conflicts
    put '/source/home:Iggy/TestPack.DELETE/conflictingfile', params: 'ASD'
    assert_response :success
    put '/source/home:Iggy/TestPack.DELETE2/conflictingfile', params: '123'
    assert_response :success

    # accepting request fails in a valid way
    login_king
    post "/request/#{id1}?cmd=changestate&newstate=accepted&comment=review1&force=1"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'expand_error' })

    # new requests are not possible anymore
    login_Iggy
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'expand_error' })
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:Iggy" package="TestPack.DELETE2" rev="2"/>
                                     <target project="home:Iggy" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'expand_error' })

    delete '/source/home:Iggy/TestPack.DELETE'
    assert_response :success
    delete '/source/home:Iggy/TestPack.DELETE2'
    assert_response :success
  end

  def test_submit_broken_request
    login_king
    put '/source/home:coolo:test/kdelibs_DEVEL_package/file', params: 'CONTENT' # just to have a revision, or we fail
    assert_response :success

    login_Iggy
    post '/request?cmd=create', params: load_backend_file('request/no_such_project')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_project' })

    post '/request?cmd=create', params: load_backend_file('request/no_such_package')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_package' })

    post '/request?cmd=create', params: load_backend_file('request/no_such_user')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' }, child: { content: /Couldn.t find User/ })

    post '/request?cmd=create', params: load_backend_file('request/no_such_group')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' }, child: { content: /Couldn.t find Group/ })

    post '/request?cmd=create', params: load_backend_file('request/no_such_role')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' }, child: { content: /Couldn.t find Role/ })

    post '/request?cmd=create', params: load_backend_file('request/no_such_target_project')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_project' })

    post '/request?cmd=create', params: load_backend_file('request/no_such_target_package')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_package' })

    post '/request?cmd=create', params: load_backend_file('request/missing_role')
    assert_response :not_found
    assert_select 'status[code] > summary', /No role specified/

    post '/request?cmd=create', params: load_backend_file('request/failing_cleanup_due_devel_package')
    assert_response :bad_request
    assert_select 'status[code] > summary', /Package is used by following packages as devel package:/
  end

  def test_set_bugowner_request
    login_Iggy
    post '/request?cmd=create', params: load_backend_file('request/set_bugowner')
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { name: 'Iggy' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { name: 'Iggy' })

    post '/request?cmd=create', params: load_backend_file('request/set_bugowner_group')
    assert_response :success
    assert_xml_tag(tag: 'group', attributes: { name: 'test_group' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id2 = node.value('id')
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag(tag: 'group', attributes: { name: 'test_group' })

    post '/request?cmd=create', params: load_backend_file('request/set_bugowner_fail')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_package' })

    post '/request?cmd=create', params: load_backend_file('request/set_bugowner_fail_unknown_user')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })

    post '/request?cmd=create', params: load_backend_file('request/set_bugowner_fail_unknown_group')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })

    # test direct put
    login_Iggy
    put "/request/#{id}", params: load_backend_file('request/set_bugowner')
    assert_response :forbidden
    put "/request/#{id2}", params: load_backend_file('request/set_bugowner_group')
    assert_response :forbidden

    login_king
    put "/request/#{id}", params: load_backend_file('request/set_bugowner')
    assert_response :success
    put "/request/#{id2}", params: load_backend_file('request/set_bugowner_group')
    assert_response :success

    # accept
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    meta = @response.body
    assert_no_xml_tag(tag: 'person', attributes: { role: 'bugowner' })
    assert_no_xml_tag(tag: 'group', attributes: { role: 'bugowner' })
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'bugowner' })
    assert_no_xml_tag(tag: 'group', attributes: { role: 'bugowner' })
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'person', attributes: { role: 'bugowner' }) # reset
    assert_xml_tag(tag: 'group', attributes: { groupid: 'test_group', role: 'bugowner' })
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'comment', content: "set_bugowner request #{id2}")
    assert_xml_tag(tag: 'requestid', content: id2)

    # cleanup
    put '/source/kde4/kdelibs/_meta', params: meta
    assert_response :success
  end

  def test_invalid_bugowner_requests
    login_Iggy
    put '/source/home:Iggy:Test/_meta', params: "<project name='home:Iggy:Test'><title></title><description></description> </project>"
    assert_response :success

    login_adrian
    post '/request?cmd=create', params: '<request>
                                   <action type="set_bugowner">
                                     <target project="home:Iggy:Test"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'invalid_record' })

    post '/request?cmd=create', params: '<request>
                                   <action type="set_bugowner">
                                     <target project="home:Iggy:Test"/>
                                     <person name="DOESNOTEXIST" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })

    post '/request?cmd=create', params: '<request>
                                   <action type="set_bugowner">
                                     <target project="home:Iggy:Test"/>
                                     <group name="DOESNOTEXIST" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })

    # cleanup
    login_Iggy
    delete '/source/home:Iggy:Test'
    assert_response :success
  end

  def test_set_bugowner_request_locked_project
    login_Iggy
    put '/source/home:Iggy:Test/_meta', params: "<project name='home:Iggy:Test'><title></title><description></description>  <lock><enable/></lock></project>"
    assert_response :success

    login_adrian
    post '/request?cmd=create', params: '<request>
                                   <action type="set_bugowner">
                                     <target project="home:Iggy:Test"/>
                                     <person name="adrian" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })
    get '/source/home:Iggy:Test/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'person', attributes: { role: 'bugowner' })

    # works with force
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get '/source/home:Iggy:Test/_meta'
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { role: 'bugowner' })

    # unlock and try with a locked package
    post '/source/home:Iggy:Test', params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success

    put '/source/home:Iggy:Test/pack/_meta', params: "<package project='home:Iggy:Test' name='pack'><title></title><description></description>  <lock><enable/></lock></package>"
    assert_response :success

    login_adrian
    post '/request?cmd=create', params: '<request>
                                   <action type="set_bugowner">
                                     <target project="home:Iggy:Test" package="pack"/>
                                     <person name="adrian" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })
    get '/source/home:Iggy:Test/pack/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'person', attributes: { role: 'bugowner' })

    # works with force
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get '/source/home:Iggy:Test/pack/_meta'
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { role: 'bugowner' })

    # cleanup
    delete '/source/home:Iggy:Test'
    assert_response :success
  end

  def test_create_request_anonymous
    # try it without anonymous - login required
    post '/request?cmd=create', params: load_backend_file('request/add_role')
    assert_xml_tag tag: 'status', attributes: { code: 'authentication_required' }
    assert_response :unauthorized

    # now try as webui if we get a different error
    post '/request?cmd=create', params: load_backend_file('request/add_role'), headers: { 'HTTP_USER_AGENT' => 'obs-webui-something' }
    assert_xml_tag tag: 'status', attributes: { code: 'anonymous_user' }
    assert_response :unauthorized
  end

  def test_add_role_request
    login_Iggy
    post '/request?cmd=create', params: load_backend_file('request/add_role')
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    post '/request?cmd=create', params: load_backend_file('request/add_role_fail')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_package' })

    post '/request?cmd=create', params: load_backend_file('request/add_role_fail')
    assert_response :not_found
  end

  def test_create_request_clone_and_superseed_it
    login_Iggy
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # do the real mbranch for default maintained packages
    reset_auth
    login_tom
    post '/source', params: { cmd: 'branch', request: id }
    assert_response :success

    # got the correct package branched ?
    get "/source/home:tom:branches:REQUEST_#{id}"
    assert_response :success
    get "/source/home:tom:branches:REQUEST_#{id}/TestPack.home_Iggy"
    assert_response :success
    get "/source/home:tom:branches:REQUEST_#{id}/TestPack.home_Iggy/_link"
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'home:Iggy', package: 'TestPack' })
    get "/source/home:tom:branches:REQUEST_#{id}/_attribute/OBS:RequestCloned"
    assert_response :success
    assert_xml_tag(tag: 'attribute', attributes: { namespace: 'OBS', name: 'RequestCloned' },
                   child: { tag: 'value', content: id })
    # cleanup
    delete "/source/home:tom:branches:REQUEST_#{id}"
    assert_response :success
  end

  def test_create_request_review_and_supersede
    login_Iggy
    travel_to(Date.new(2010, 7, 12))
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # add reviewer
    login_Iggy
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom', when: '2010-07-12T00:00:00' })
    # try update comment
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=tom&comment=blahfasel"
    assert_response :forbidden

    # update comment for real
    request = BsRequest.find_by_number(id)
    h1 = request.request_history_elements
    hr1 = request.history_elements
    login_tom
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=tom&comment=blahfasel"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(parent: { tag: 'review', attributes: { by_user: 'tom', when: '2010-07-12T00:00:00' } }, tag: 'comment', content: 'blahfasel')
    request = BsRequest.find_by_number(id)
    h2 = request.request_history_elements
    hr2 = request.history_elements
    assert_equal h2.length - h1.length, 0 # no change
    assert_equal hr2.length - hr1.length, 1 # review accepted

    # invalid state
    post "/request/#{id}?cmd=changereviewstate&newstate=INVALID&by_user=tom&comment=blahfasel"
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'request_not_modifiable' })

    # superseded review
    travel_to(Date.new(2010, 7, 13))
    post "/request/#{id}?cmd=changereviewstate&newstate=superseded&by_user=tom&superseded_by=1"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    # state and time updated
    assert_xml_tag(tag: 'review', attributes: { state: 'superseded', by_user: 'tom', when: '2010-07-13T00:00:00' })

    # another final state is not allowed
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom&comment=blahfasel"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'review_change_state_no_permission' })
    assert_xml_tag(tag: 'summary', content: 'The request is neither in state review nor new')

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'superseded', superseded_by: '1' })
  end

  def test_create_request_approve_and_review
    login_Iggy

    req = <<~XML_REQUEST
      <request>
        <action type="submit">
          <source project="home:Iggy" package="TestPack" rev="1"/>
          <target project="home:fred" package="foopkg"/>
        </action>
        <review state="new" by_group="test_group"/>
        <review state="new" by_user="adrian"/>
      </request>
    XML_REQUEST
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    login_tom
    # try to approve without being empowered
    post "/request/#{id}?cmd=approve"
    assert_response :forbidden

    # approve for real
    login_fred # is the maintainer of target
    post "/request/#{id}?cmd=approve"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review', approver: 'fred' })

    # just process reviews
    login_king
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group&comment=blahfasel"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review', approver: 'fred' })
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&comment=blahfasel"
    assert_response :success

    # got accepted
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'accepted', who: 'fred', approver: 'fred' })

    get '/source/home:fred/foopkg/_history'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    first_node = node.elements('revision').first
    assert_equal 'fred', first_node['user']
    assert_equal id, first_node['requestid']

    # cleanup
    delete '/source/home:fred/foopkg'
    assert_response :success
  end

  def test_create_request_with_approver
    req_template = <<~XML_REQUEST
      <request>
        <action type="submit">
          <source project="home:Iggy" package="TestPack" rev="1"/>
          <target project="home:fred" package="foopkg"/>
        </action>
        <review state="new" by_group="test_group"/>
        <state name="new" approver="%<approver>s"/>
      </request>
    XML_REQUEST

    login_Iggy
    # request creation fails because we are not admin
    post '/request?cmd=create', params: format(req_template, approver: 'fred')
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'create_bs_request_not_authorized' })
    assert_xml_tag(tag: 'summary', content: 'Sorry, you are not authorized to create this bs request.')

    # request creation succeeds because we are "Iggy"
    post '/request?cmd=create', params: format(req_template, approver: 'Iggy')
    assert_response :success

    # as admin it should work
    login_king
    # request creation succeeds because we are "Iggy"
    post '/request?cmd=create', params: format(req_template, approver: 'Iggy')
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # accept review
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success

    # the request was not accepted because the approver "Iggy" has no
    # sufficient permissions to create a new package in the "home:fred"
    # project => the request is automatically revoked
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state',
                   attributes: { name: 'revoked', who: 'Iggy',
                                 approver: 'Iggy' })
  end

  def test_create_request_and_supersede
    login_Iggy
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    login_tom
    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })

    # target says supersede it due to another existing request
    login_adrian
    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'superseded', superseded_by: '1' })
  end

  def test_create_request_and_supersede_as_creator
    login_Iggy
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    post "/request/#{id}?cmd=changestate&newstate=superseded&superseded_by=1"
    assert_response :success
  end

  def test_create_request_and_decline_review
    login_Iggy
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # add reviewer
    login_Iggy
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom' })

    login_tom
    post "/request/#{id}?cmd=changereviewstate&newstate=declined"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'review_not_specified' })
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=tom"
    assert_response :success
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'review_change_state_no_permission' })

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })

    # add review not permitted anymore
    post "/request/#{id}?cmd=addreview&by_user=king"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'review_change_state_no_permission' })
  end

  # MeeGo BOSS: is using multiple reviews by same user for each step
  def test_create_request_and_multiple_reviews
    # the birthday of J.K.
    travel_to(Date.new(2010, 7, 12))

    login_Iggy
    post('/request?cmd=create', params: "<request>
                                   <action type='add_role'>
                                     <target project='home:Iggy' package='TestPack' />
                                     <person name='Iggy' role='reviewer' />
                                    </action>
                                  </request>")

    assert_response :success

    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })
    assert node['id']
    id = node.value(:id)

    # add reviewer
    login_Iggy
    travel(1.second) # 0:0:1 review added
    post "/request/#{id}?cmd=addreview&by_user=tom&comment=couldyou"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom' })

    # accept review
    login_tom
    travel(1.second) # 0:0:2 tom accepts review
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom&comment=review1"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })

    # readd reviewer
    login_Iggy
    travel(1.second) # 0:0:3 yet another review for tom
    post "/request/#{id}?cmd=addreview&by_user=tom&comment=overlooked"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom' })

    # accept review
    login_tom
    travel(1.second) # 0:0:4 yet another review accept by tom
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=tom&comment=review2"
    assert_response :success

    # check review comments are the same
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(parent: { tag: 'review', attributes: { by_user: 'tom' } }, tag: 'comment', content: 'review1')
    assert_xml_tag(parent: { tag: 'review', attributes: { by_user: 'tom' } }, tag: 'comment', content: 'review2')

    # reopen a review
    login_tom
    travel(1.second) # 0:0:5 reopened from tom
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=tom&comment=reopen2"
    assert_response :success
    get "/request/#{id}?withhistory=1"
    assert_response :success

    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
    assert_xml_tag(parent: { tag: 'review', attributes: { state: 'accepted', by_user: 'tom' } }, tag: 'comment', content: 'review1')
    assert_xml_tag(parent: { tag: 'review', attributes: { state: 'new', by_user: 'tom' } }, tag: 'comment', content: 'reopen2')
    node = Xmlhash.parse(@response.body)
    assert_equal({ 'id' => id.to_s,
                   'creator' => 'Iggy',
                   'action' => {
                     'type' => 'add_role',
                     'target' => { 'project' => 'home:Iggy', 'package' => 'TestPack' },
                     'person' => { 'name' => 'Iggy', 'role' => 'reviewer' }
                   },
                   'state' => {
                     'name' => 'review',
                     'who' => 'tom',
                     'when' => '2010-07-12T00:00:05',
                     'created' => '2010-07-12T00:00:00',
                     'comment' => 'reopen2'
                   },
                   'review' => [{
                     'state' => 'accepted',
                     'when' => '2010-07-12T00:00:02',
                     'who' => 'tom',
                     'by_user' => 'tom',
                     'comment' => 'review1',
                     'history' => {
                       'who' => 'tom',
                       'when' => '2010-07-12T00:00:02',
                       'description' => 'Review got accepted',
                       'comment' => 'review1'
                     }
                   }, {
                     'state' => 'new',
                     'when' => '2010-07-12T00:00:05',
                     'who' => 'tom',
                     'by_user' => 'tom',
                     'comment' => 'reopen2',
                     'history' => [{ 'who' => 'tom', 'when' => '2010-07-12T00:00:04',
                                     'description' => 'Review got accepted',
                                     'comment' => 'review2' },
                                   { 'who' => 'tom', 'when' => '2010-07-12T00:00:05',
                                     'description' => 'Review got reopened',
                                     'comment' => 'reopen2' }]
                   }],
                   'history' => [
                     { 'who' => 'Iggy',
                       'when' => '2010-07-12T00:00:00',
                       'description' => 'Request created' },
                     { 'description' => 'Request got a new review request',
                       'who' => 'Iggy',
                       'when' => '2010-07-12T00:00:01',
                       'comment' => 'couldyou' },
                     { 'description' => 'Request got reviewed',
                       'who' => 'tom',
                       'when' => '2010-07-12T00:00:02',
                       'comment' => 'review1' },
                     { 'description' => 'Request got a new review request',
                       'who' => 'Iggy',
                       'when' => '2010-07-12T00:00:03',
                       'comment' => 'overlooked' },
                     { 'description' => 'Request got reviewed',
                       'who' => 'tom',
                       'when' => '2010-07-12T00:00:04',
                       'comment' => 'review2' }
                   ] }, node)
  end

  def test_assign_from_group
    login_Iggy
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # add reviewer group
    login_Iggy
    post "/request/#{id}?cmd=addreview&by_user=king"
    assert_response :success
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    post "/request/#{id}?cmd=addreview&by_group=test_group_b"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })

    # adrian assigns to Iggy and reverts
    login_adrian
    get "/request/#{id}"
    assert_response :success
    assert_no_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'Iggy' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'king' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_group: 'test_group' })
    post "/request/#{id}?by_group=test_group&cmd=assignreview&reviewer=Iggy", params: 'Iggy, please have a look'
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'Iggy' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'king' })
    assert_xml_tag(tag: 'review', attributes: { state: 'accepted', by_group: 'test_group' })
    # stealing the review of king is not working
    post "/request/#{id}?by_group=test_group&cmd=assignreview&reviewer=king&revert=1", params: 'try to kill it'
    assert_response :not_found
    assert_xml_tag tag: 'summary', content: 'Not an assigned review'
    # Iggy went home without telling....
    post "/request/#{id}?by_group=test_group&cmd=assignreview&reviewer=Iggy&revert=1", params: 'ups, drop it again'
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_no_xml_tag(tag: 'review', attributes: { by_user: 'Iggy' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'king' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_group: 'test_group' })

    # adrian assigns to adrian_downloader
    login_adrian
    get "/request/#{id}"
    assert_response :success
    assert_no_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'adrian_downloader' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'king' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_group: 'test_group' })
    post "/request/#{id}?by_group=test_group&cmd=assignreview&reviewer=adrian_downloader", params: 'adrian_downloader, please have a look'
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'adrian_downloader' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'king' })
    assert_xml_tag(tag: 'review', attributes: { state: 'accepted', by_group: 'test_group' })

    login_adrian_downloader
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian_downloader"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { state: 'accepted', by_user: 'adrian_downloader' })

    # adrian_downloader assigns to himself
    post "/request/#{id}?by_group=test_group_b&cmd=assignreview&reviewer=adrian_downloader", params: 'I will work on it as well'
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'adrian_downloader' })
    assert_no_xml_tag(tag: 'review', attributes: { state: 'accepted', by_user: 'adrian_downloader' })

    # ah, no.....
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=adrian_downloader"
    assert_response :success

    # validate
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })
    assert_xml_tag(tag: 'review', attributes: { state: 'declined', by_user: 'adrian_downloader' })
    assert_xml_tag(tag: 'review', attributes: { state: 'accepted', by_group: 'test_group' })
    assert_xml_tag(tag: 'review', attributes: { state: 'accepted', by_group: 'test_group_b' })
  end

  def test_change_review_state_after_leaving_review_phase
    login_Iggy
    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # add reviewer
    login_Iggy
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom' })

    # add reviewer group
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })

    login_adrian
    post "/request/#{id}?newstate=new&by_group=test_group&cmd=changereviewstate", params: 'adrian is looking'
    assert_response :success
    post "/request/#{id}?newstate=new&by_group=test_group&cmd=changereviewstate", params: 'adrian does not care'
    assert_response :success

    login_tom
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_user=tom"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })
    assert_xml_tag(tag: 'review', attributes: { state: 'declined', by_user: 'tom' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_group: 'test_group' },
                   child: { tag: 'comment', content: 'adrian does not care' })

    # change review not permitted anymore
    login_tom
    post "/request/#{id}?cmd=changereviewstate&newstate=declined&by_group=test_group"
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'review_change_state_no_permission' }

    # search this request and verify that all reviews got rendered.
    get '/search/request', params: { match: "[@id=#{id}]" }
    assert_response :success
    get '/search/request', params: { match: "[review/@by_user='adrian']" }
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'adrian' })
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom' })
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })
  end

  def test_search_by_creator
    login_Iggy
    get '/search/request', params: { match: "@creator='Iggy'" }
    assert_response :success
    assert_xml_tag(tag: 'request', attributes: { id: '6', creator: 'Iggy' })
  end

  def test_search_and_involved_requests
    req = load_backend_file('request/1')

    # claim to be someone else
    login_Iggy
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'request_save_error' })
    assert_xml_tag(tag: 'summary', content: 'Admin permissions required to set request creator to foreign user')

    # make sure there is at least one request
    login_tom
    post '/request?cmd=create', params: req
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id = node.value :id

    # admin can define requests in the name of other people
    login_king
    put("/request/#{id}", params: load_backend_file('request/1'))
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { who: 'tom' })

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'request', attributes: { id: id })
    assert_xml_tag(tag: 'state', attributes: { name: 'new', who: 'tom' })

    # via GET
    login_Iggy
    get '/search/request', params: { match: "(state/@name='new' or state/@name='review') and (action/target/@project='kde4' and action/target/@package='wpa_supplicant')" }
    assert_response :success
    assert_xml_tag(tag: 'request', attributes: { id: id })

    # via POST
    post '/search/request', params: Addressable::URI.encode("match=(state/@name='new' or state/@name='review') and (action/target/@project='kde4' and action/target/@package='wpa_supplicant')")
    assert_response :success
    assert_xml_tag(tag: 'request', attributes: { id: id })

    # search history
    get '/search/request', params: { match: "history/@who='Iggy'" }
    assert_response :success
    assert_no_xml_tag(tag: 'history')
    get '/search/request', params: { match: "history/@who='Iggy'", withhistory: '1' }
    assert_response :success
    assert_xml_tag(tag: 'history', attributes: { who: 'Iggy' })

    # test "osc rq"
    get '/search/request', params: { match: "(state/@who='tom' or history/@who='tom')" }
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 6 }

    # old style listing
    get '/request'
    assert_response :success
    assert_xml_tag(tag: 'directory', child: { tag: 'entry' })

    # collection view
    get '/request?view=collection'
    assert_response :not_found

    # collection of user involved requests
    get '/request?view=collection&user=Iggy&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    if @ENABLE_BROKEN_TEST
      # FIXME: there is no code in this test creating request from HiddenProject

      assert_xml_tag(tag: 'source', attributes: { project: 'HiddenProject', package: 'pack' })
    end

    # collection for given package
    get '/request?view=collection&project=kde4&package=wpa_supplicant&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'collection', attributes: { matches: '1' })
    assert_xml_tag(tag: 'target', attributes: { project: 'kde4', package: 'wpa_supplicant' })
    assert_xml_tag(tag: 'request', attributes: { id: id })

    # collection for given project
    get '/request?view=collection&project=kde4&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'collection', attributes: { matches: '4' })

    # tom searches for all request of adrian, but adrian has one in a hidden project which must not be viewable ...
    login_tom
    get '/request?view=collection&user=adrian&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_no_xml_tag(tag: 'target', attributes: { project: 'HiddenProject' })

    return unless @ENABLE_BROKEN_TEST

    # ... but adrian gets it
    login_adrian
    get '/request?view=collection&user=adrian&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'target', attributes: { project: 'HiddenProject' })
  end

  def test_release_package_via_request
    login_adrian
    # define manual release target
    put '/source/home:adrian:RT/_meta', params: "<project name='home:adrian:RT'> <title/> <description/>
          <repository name='rt'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    run_scheduler('i586')
    run_scheduler('x86_64')

    login_Iggy
    get '/source/home:Iggy/_meta'
    assert_response :success
    orig_project_meta = @response.body
    doc = REXML::Document.new(@response.body)
    rt = doc.elements['/project/repository'].add_element 'releasetarget'
    rt.add_attribute(REXML::Attribute.new('project', 'home:adrian:RT'))
    rt.add_attribute(REXML::Attribute.new('repository', 'rt'))
    rt.add_attribute(REXML::Attribute.new('trigger', 'manual'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success

    # create request
    post '/request?cmd=create&ignore_build_state=1', params: "<request>
                                   <action type='release'>
                                     <source project='home:Iggy' package='TestPack' />
                                   </action>
                                   <state name='new' />
                                 </request>"
    assert_response :success
    assert_xml_tag tag: 'source', attributes: { project: 'home:Iggy', package: 'TestPack' }
    assert_xml_tag tag: 'target', attributes: { project: 'home:adrian:RT', package: 'TestPack', repository: 'rt' }
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']

    # release via request, ignoring reviewers
    login_adrian
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }

    # process events
    run_scheduler('i586')

    # verify result
    get '/source/home:adrian:RT'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPack' }

    # check released binaries
    get '/build/home:Iggy/10.2/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }

    get '/build/home:adrian:RT/rt/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }

    # cleanup
    login_Iggy
    put '/source/home:Iggy/_meta', params: orig_project_meta
    assert_response :success
    login_adrian
    delete '/source/home:adrian:RT'
    assert_response :success
  end

  def test_process_devel_request
    login_king

    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'devel', attributes: { project: 'BaseDistro', package: 'pack1' }
    oldmeta = @response.body

    rq = '<request>
           <action type="change_devel">
             <source project="BaseDistro" package="pack1"/>
             <target project="home:Iggy" package="TestPack"/>
           </action>
           <state name="new" />
         </request>'

    post '/request?cmd=create', params: rq
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # and create a delete request
    rq = '<request>
           <action type="delete">
             <target project="BaseDistro" package="pack1"/>
           </action>
           <state name="new" />
         </request>'

    post '/request?cmd=create', params: rq
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    iddelete = node.value(:id)

    # try to approve change_devel
    login_adrian
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden

    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    assert_xml_tag tag: 'devel', attributes: { project: 'BaseDistro', package: 'pack1' }

    # try to create delete request
    rq = '<request>
           <action type="delete">
             <target project="BaseDistro" package="pack1"/>
           </action>
           <state name="new" />
         </request>'

    post '/request?cmd=create', params: rq
    # this used to verify it can't delete devel links, but that was changed
    assert_response :success

    # try to delete package via old request, it should fail
    login_king
    post "/request/#{iddelete}?cmd=changestate&newstate=accepted"
    assert_response :bad_request

    # cleanup
    put '/source/home:Iggy/TestPack/_meta', params: oldmeta.dup
    assert_response :success
  end

  def test_reject_request_creation
    login_Iggy

    # block request creation in project
    post '/source/home:Iggy/_attribute', params: "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Go Away</value> </attribute> </attributes>"
    assert_response :success

    rq = '<request>
           <action type="submit">
             <source project="BaseDistro" package="pack1" rev="1"/>
             <target project="home:Iggy" package="TestPack"/>
           </action>
           <state name="new" />
         </request>'

    post '/request?cmd=create', params: rq
    assert_response :forbidden
    assert_match(/Go Away/, @response.body)
    assert_xml_tag tag: 'status', attributes: { code: 'request_rejected' }

    # just for submit actions
    post '/source/home:Iggy/_attribute', params: "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>No Submits</value> <value>submit</value> </attribute> </attributes>"
    assert_response :success
    post '/request?cmd=create', params: rq
    assert_response :forbidden
    assert_match(/No Submits/, @response.body)
    assert_xml_tag tag: 'status', attributes: { code: 'request_rejected' }
    # but it works when blocking only for others
    post '/source/home:Iggy/_attribute', params: "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Submits welcome</value> <value>delete</value> <value>set_bugowner</value> </attribute> </attributes>"
    assert_response :success
    post '/request?cmd=create', params: rq
    assert_response :success

    # block request creation in package
    post '/source/home:Iggy/TestPack/_attribute', params: "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Package blocked</value> </attribute> </attributes>"
    assert_response :success

    post '/request?cmd=create', params: rq
    assert_response :forbidden
    assert_match(/Package blocked/, @response.body)
    assert_xml_tag tag: 'status', attributes: { code: 'request_rejected' }
    # remove project attribute lock
    delete '/source/home:Iggy/_attribute/OBS:RejectRequests'
    assert_response :success
    # still not working
    post '/request?cmd=create', params: rq
    assert_response :forbidden
    assert_match(/Package blocked/, @response.body)
    assert_xml_tag tag: 'status', attributes: { code: 'request_rejected' }

    # just for submit actions
    post '/source/home:Iggy/TestPack/_attribute', params: "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>No Submits</value> <value>submit</value> </attribute> </attributes>"
    assert_response :success
    post '/request?cmd=create', params: rq
    assert_response :forbidden
    assert_match(/No Submits/, @response.body)
    assert_xml_tag tag: 'status', attributes: { code: 'request_rejected' }
    # but it works when blocking only for others
    post '/source/home:Iggy/TestPack/_attribute',
         params: "<attributes><attribute namespace='OBS' name='RejectRequests'> <value>Submits welcome</value> <value>delete</value> <value>set_bugowner</value> </attribute> </attributes>"
    assert_response :success
    post '/request?cmd=create', params: rq
    assert_response :success

    # FIXME: test with request without target

    # cleanup
    delete '/source/home:Iggy/TestPack/_attribute/OBS:RejectRequests'
    assert_response :success
  end

  def test_submit_request_from_hidden_project_and_hidden_source
    login_tom
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="HiddenProject" package="pack" rev="1"/>
                                     <target project="home:tom" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :not_found
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="SourceprotectedProject" package="pack" rev="1"/>
                                     <target project="home:tom" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :forbidden

    prepare_request_with_user('hidden_homer', 'buildservice')
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="HiddenProject" package="pack" rev="1"/>
                                     <target project="kde4" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="SourceprotectedProject" package="pack" rev="1"/>
                                     <target project="kde4" package="DUMMY"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success
  end

  def test_auto_revoke_when_source_gets_removed_maintenance_incident
    login_tom
    post '/source/kde4/kdebase', params: { cmd: :branch }
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:kde4" package="kdebase" rev="1"/>
                                     <target project="My:Maintenance" releaseproject="BaseDistro3" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id1 = node.value(:id)

    login_king
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response :success

    # delete projects
    login_tom
    delete '/source/home:tom:branches:kde4'
    assert_response :success

    # request got automatically revoked
    get "/request/#{id1}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })

    # test revoke
    login_adrian
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response :forbidden
  end

  def test_auto_revoke_when_source_gets_removed_submit
    login_tom
    post '/source/kde4/kdebase', params: { cmd: :branch }
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:tom:branches:kde4" package="kdebase" rev="0"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'kde4', package: 'kdebase' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id1 = node.value(:id)

    post '/source/home:tom:branches:kde4/kdebase', params: { cmd: :branch }
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="home:tom:branches:home:tom:branches:kde4" package="kdebase" rev="0"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'home:tom:branches:kde4', package: 'kdebase' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    # id2 = node.value(:id)

    # delete projects
    delete '/source/home:tom:branches:home:tom:branches:kde4'
    assert_response :success
    delete '/source/home:tom:branches:kde4'
    assert_response :success

    # request got automatically revoked
    get "/request/#{id1}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })

    # test decline and revoke
    login_adrian
    post "/request/#{id1}?cmd=changestate&newstate=declined"
    assert_response :forbidden # set back is not allowed
  end

  def test_revoke_and_decline_when_projects_are_not_existing_anymore
    login_tom

    # test revoke, the request is part of fixtures
    post '/request/3?cmd=changestate&newstate=revoked'
    assert_response :success
    # missing target project
    post '/request/2?cmd=changestate&newstate=revoked'
    assert_response :success

    # missing source project
    post '/request/1?cmd=changestate&newstate=declined'
    assert_response :forbidden

    login_adrian
    post '/request/1?cmd=changestate&newstate=declined'
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

    post '/request?cmd=create', params: req
    assert_response :unauthorized
    assert_select 'status[code] > summary', /Authentication required/

    # create request by non-maintainer => validate created review item
    login_tom
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    assert_xml_tag(tag: 'review', attributes: { by_project: 'home:Iggy', by_package: 'TestPack' })
    assert_xml_tag(tag: 'review', attributes: { by_user: 'adrian' })
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id_by_package = node.value(:id)

    # find requests which are not in review
    get '/request?view=collection&user=Iggy&states=new'
    assert_response :success
    assert_no_xml_tag(tag: 'review', attributes: { by_project: 'home:Iggy', by_package: 'TestPack' })
    # find reviews
    get '/request?view=collection&user=Iggy&states=review&reviewstates=new&roles=reviewer'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'review', attributes: { by_project: 'home:Iggy', by_package: 'TestPack' })

    # test search via xpath as well
    get '/search/request', params: { match: "state/@name='review' and review[@by_project='home:Iggy' and @state='new']" }
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'review', attributes: { by_project: 'home:Iggy', by_package: 'TestPack' })

    # create request by maintainer
    login_Iggy
    req = load_backend_file('request/submit_without_target')
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_target_project' })

    req = load_backend_file('request/works')
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    assert_no_xml_tag(tag: 'review', attributes: { by_project: 'home:Iggy', by_package: 'TestPack' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # add reviewer
    login_tom
    post "/request/#{id}?cmd=addreview&by_user=adrian"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'add_review_not_permitted' })

    login_Iggy
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_user: 'tom' })

    login_tom
    post "/request/#{id}?cmd=addreview&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })

    # test search via xpath as well
    get '/search/request', params: { match: "state/@name='review' and review[@by_group='test_group' and @state='new']" }
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })

    # invalid review, by_project is missing
    post "/request/#{id}?cmd=addreview&by_package=kdelibs"
    assert_response :bad_request

    post "/request/#{id}?cmd=addreview&by_project=kde4&by_package=kdelibs"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_project: 'kde4', by_package: 'kdelibs' })

    post "/request/#{id}?cmd=addreview&by_project=home:tom"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { by_project: 'home:tom', by_package: nil })

    # and revoke it
    reset_auth
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :unauthorized

    login_tom
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :forbidden
    post '/request/ILLEGAL_CONTENT?cmd=changestate&newstate=revoked'
    assert_response :not_found
    # Rails does not allow /request/:id to match non-integers, so there is no XML generated for 404
    # assert_xml_tag tag: 'status', attributes: {code: 'not_found'}

    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })

    # decline by_package review
    reset_auth
    post "/request/#{id_by_package}?cmd=changereviewstate&newstate=declined&by_project=home:Iggy&by_package=TestPack"
    assert_response :unauthorized

    login_tom
    post "/request/#{id_by_package}?cmd=changereviewstate&newstate=declined&by_project=home:Iggy&by_package=TestPack"
    assert_response :forbidden

    login_Iggy
    post "/request/#{id_by_package}?cmd=changereviewstate&newstate=declined&by_project=home:Iggy&by_package=TestPack"
    assert_response :success

    get "/request/#{id_by_package}"
    assert_response :success
    assert_xml_tag(tag: 'review', attributes: { state: 'declined', by_project: 'home:Iggy', by_package: 'TestPack', who: 'Iggy' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'adrian' })
    assert_xml_tag(tag: 'review', attributes: { state: 'new', by_group: 'test_group' })
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })

    # reopen with new, but state should become review due to open review
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
  end

  def test_submit_cleanup_in_not_writable_source
    login_Iggy
    %w[cleanup update].each do |modify|
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
      post '/request?cmd=create', params: req
      assert_response :forbidden
      assert_xml_tag(tag: 'status', attributes: { code: 'lacking_maintainership' })
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
    post '/request?cmd=create', params: req
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'lacking_maintainership' })
  end

  def test_makeoriginolder_request
    login_Iggy

    put '/source/home:Iggy:Apache/_meta', params: "<project name='home:Iggy:Apache'> <title/> <description/>
                                         <link project='Apache'/>
                                        </project>"
    assert_response :success

    req = "<request>
            <action type='submit'>
              <source project='Apache' package='apache2' rev='1' />
              <target project='home:Iggy:Apache' package='apache2' />
              <options>
                <makeoriginolder>true</makeoriginolder>
              </options>
            </action>
            <description/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?
    # no write permission
    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=But+I+want+it"
    assert_response :forbidden
    post "/request/#{id}?cmd=changestate&newstate=revoked&comment=take+it+back"
    assert_response :success
    post "/request/#{id}?cmd=changestate&newstate=new&comment=try+again"
    assert_response :success

    # approvereview
    login_fred
    post "/request/#{id}?cmd=changereviewstate&by_project=Apache&by_package=apache2&newstate=accepted"
    assert_response :success

    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=But+I+want+it"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1&comment=But+I+want+it"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })

    delete '/source/home:Iggy:Apache'
    assert_response :success
  end

  def test_reopen_a_review_declined_request
    %w[new review].each do |newstate|
      login_Iggy
      post '/source/Apache/apache2', params: { cmd: :branch }
      assert_response :success

      # do a commit
      put '/source/home:Iggy:branches:Apache/apache2/file', params: 'dummy'
      assert_response :success

      req = "<request>
              <action type='submit'>
                <source project='home:Iggy:branches:Apache' package='apache2' rev='2' />
              </action>
              <description/>
            </request>"
      post '/request?cmd=create', params: req
      assert_response :success
      assert_xml_tag(tag: 'state', attributes: { name: 'new' })
      node = Xmlhash.parse(@response.body)
      assert node['id']
      id = node.value(:id)

      # add reviewer
      post "/request/#{id}?cmd=addreview&by_user=fred"
      assert_response :success
      get "/request/#{id}"
      assert_response :success
      assert_xml_tag(tag: 'review', attributes: { by_user: 'fred' })

      # reviewer declines
      login_fred
      post "/request/#{id}?cmd=changereviewstate&by_user=fred&newstate=declined"
      assert_response :success
      get "/request/#{id}"
      assert_response :success
      assert_xml_tag(tag: 'review', attributes: { state: 'declined', by_user: 'fred' })

      # reopen it again and validate that the request opens the review as well
      login_Iggy
      post "/request/#{id}?cmd=changestate&newstate=#{newstate}&comment=But+I+want+it"
      assert_response :success
      get "/request/#{id}"
      assert_response :success
      assert_xml_tag(tag: 'review', attributes: { state: 'new', by_user: 'fred' })
      assert_xml_tag(tag: 'state', attributes: { name: 'review' })

      # cleanup
      delete '/source/home:Iggy:branches:Apache'
      assert_response :success
    end
  end

  def test_reopen_revoked_and_declined_request
    login_Iggy
    post '/source/Apache/apache2', params: { cmd: :branch }
    assert_response :success

    # do a commit
    put '/source/home:Iggy:branches:Apache/apache2/file', params: 'dummy'
    assert_response :success

    req = "<request>
            <action type='submit'>
              <source project='home:Iggy:branches:Apache' package='apache2' rev='0' />
            </action>
            <description/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # revoke it
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })

    # and reopen it as a non-maintainer is not working
    login_adrian
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :forbidden
    # and reopen it as a non-source-maintainer is not working
    prepare_request_with_user('fredlibs', 'buildservice')
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :forbidden

    # reopen it again
    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })

    # target is declining it
    login_fred
    post "/request/#{id}?cmd=changestate&newstate=declined"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })

    # find it as I am the creator
    get '/request?view=collection&states=declined&roles=creator'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'request', attributes: { id: id })

    # find it as another user
    login_adrian
    get '/request?view=collection&user=Iggy&states=declined&roles=creator'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'request', attributes: { id: id })

    # and reopen it as a non-maintainer is not working
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :forbidden

    # and reopen it as a different maintainer from target
    prepare_request_with_user('fredlibs', 'buildservice')
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })

    # cleanup
    login_Iggy
    delete '/source/home:Iggy:branches:Apache'
    assert_response :success
  end

  def test_all_action_types
    req = load_backend_file('request/cover_all_action_types_request')
    login_Iggy

    # create kdebase package
    post '/source/kde4/kdebase', params: { cmd: :branch }
    assert_response :success
    post '/request?cmd=create', params: req
    assert_response :success
    put '/source/home:Iggy:branches:kde4/kdebase/change', params: 'avoid dropped submit action'
    assert_response :success
    post '/request?cmd=create', params: req
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)
    assert_xml_tag(tag: 'review', attributes: { by_user: 'adrian', state: 'new' })

    # do not accept request in review state
    get "/request/#{id}"
    login_fred
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_match(/Request is in review state/, @response.body)

    # approve reviews
    login_adrian
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })

    # a review has been added because we are not maintainer of current devel package, accept it.
    login_king
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
    assert_xml_tag(tag: 'review', attributes: { by_project: 'home:coolo:test', by_package: 'kdelibs_DEVEL_package' })
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_project=home:coolo:test&by_package=kdelibs_DEVEL_package"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })

    # reopen the review
    login_tom
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_group=INEXISTENT"
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_user=INEXISTENT"
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })
    post "/request/#{id}?cmd=changereviewstate&newstate=new&by_project=home:coolo:test&by_package=kdelibs_DEVEL_package"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
    # and accept it again
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_project=home:coolo:test&by_package=kdelibs_DEVEL_package"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })

    # validate our existing test data and fixtures
    login_king
    get '/source/home:Iggy/ToBeDeletedTestPack/_meta'
    assert_response :success
    get '/source/home:fred:DeleteProject/_meta'
    assert_response :success
    get '/source/kde4/Testing/myfile'
    assert_response :not_found
    get '/source/kde4/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'bugowner' })
    assert_no_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'maintainer' })
    assert_no_xml_tag(tag: 'group', attributes: { groupid: 'test_group', role: 'reader' })
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'devel', attributes: { project: 'home:Iggy', package: 'TestPack' })
    assert_no_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'bugowner' })
    assert_no_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'maintainer' })
    assert_no_xml_tag(tag: 'group', attributes: { groupid: 'test_group', role: 'reader' })

    # Accept will fail because Fred does not have permissions on the source package
    # which is required because of the InitializeDevelPackage attribute on kde4
    login_fred
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_match(/No permission to initialize the source package as a devel package/, @response.body)

    # We need to set permissions on the source because of the InitializeDevelPackage attribute on kde4 project
    login_king
    put '/source/home:Iggy:branches:kde4/_meta', params: "<project name='home:Iggy:branches:kde4'><title/><description/><person userid='fred' role='maintainer'/></project>"
    assert_response :success

    # Successful accept the request
    login_fred
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    # Validate the executed actions
    get '/source/home:Iggy:branches:kde4/BranchPack/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'kde4', package: 'Testing' }
    get '/source/home:Iggy/ToBeDeletedTestPack'
    assert_response :not_found
    get '/source/home:fred:DeleteProject'
    assert_response :not_found
    get '/source/kde4/Testing/myfile'
    assert_response :success
    get '/source/kde4/_meta'
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'bugowner' })
    assert_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'maintainer' })
    assert_xml_tag(tag: 'group', attributes: { groupid: 'test_group', role: 'reader' })
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    assert_xml_tag(tag: 'devel', attributes: { project: 'home:Iggy', package: 'TestPack' })
    assert_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'bugowner' })
    assert_xml_tag(tag: 'person', attributes: { userid: 'Iggy', role: 'maintainer' })
    assert_xml_tag(tag: 'group', attributes: { groupid: 'test_group', role: 'reader' })

    # cleanup
    login_king
    delete '/source/kde4/Testing'
    assert_response :success
    post '/source/home:fred:DeleteProject', params: { cmd: 'undelete' }
    assert_response :success
    post '/source/home:Iggy/ToBeDeletedTestPack', params: { cmd: 'undelete' }
    assert_response :success
  end

  def test_submit_with_review
    req = load_backend_file('request/submit_with_review')

    login_Iggy
    post '/request?cmd=create', params: req
    assert_response :success
    # we upload 2 and 2 default reviewers are added
    assert_xml_tag(children: { only: { tag: 'review' }, count: 4 })
    assert_xml_tag(tag: 'state', attributes: { name: 'review' }, parent: { tag: 'request' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # test search
    get '/request?view=collection&group=test_group&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    # be sure we have not 2 invalidating the limit test
    assert_no_xml_tag(tag: 'collection', attributes: { matches: 2 })

    # test limit
    get '/request?view=collection&group=test_group&states=new,review&limit=2'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'collection', attributes: { matches: 2 })

    # try to break permissions
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_match(/Request is in review state./, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response :forbidden
    assert_match(/review state change is not permitted for/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :forbidden
    assert_match(/review state change for group test_group is not permitted for Iggy/, @response.body)
    post '/request/987654321?cmd=changereviewstate&newstate=accepted&by_group=test_group'
    assert_response :not_found
    assert_match(/Couldn't find BsRequest/, @response.body)

    # Only partly matching by_ arguments
    login_adrian
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&by_group=test_group_b"
    assert_response :forbidden
    assert_match(/review state change for group test_group_b is not permitted for adrian/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&by_project=BaseDistro"
    assert_response :forbidden
    assert_match(/review state change for project BaseDistro is not permitted for adrian/, @response.body)
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian&by_project=BaseDistro&by_package=pack2"
    assert_response :forbidden
    assert_match(%r{review state change for package BaseDistro/pack2 is not permitted for adrian}, @response.body)

    # approve reviews for real
    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_user=adrian"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' },
                   parent: { tag: 'request' }) # remains in review state

    post "/request/#{id}?cmd=changereviewstate&newstate=accepted&by_group=test_group"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' },
                   parent: { tag: 'request' }) # switch to new after last review

    # Accept will fail because adrian does not have permissions on the source
    # which is required because of the InitializeDevelPackage attribute on kde4
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :forbidden
    assert_match(/No permission to initialize the source package as a devel package/, @response.body)

    # Adding adrian as maintainoer of the source
    login_Iggy
    get '/source/home:Iggy/_meta'
    iggy_meta = @response.body
    put '/source/home:Iggy/_meta', params: "<project name='home:Iggy'><title/><description/><person userid='adrian' role='maintainer'/></project>"

    assert_response :success

    login_adrian
    # approve accepted and check initialized devel package
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get '/source/kde4/Testing/_meta'
    assert_response :success
    assert_xml_tag(tag: 'devel', attributes: { project: 'home:Iggy', package: 'TestPack' })

    # cleanup
    login_king
    delete '/source/home:Iggy/TestPack/_link'
    assert_response :success
    delete '/source/kde4/Testing'
    assert_response :success
    login_Iggy
    put '/source/home:Iggy/_meta', params: iggy_meta
  end

  def test_reviewer_added_when_source_maintainer_is_missing
    # create request
    login_tom
    req = "<request>
            <action type='submit'>
              <source project='BaseDistro2.0' package='pack2' rev='1' />
              <target project='home:tom' package='pack2' />
            </action>
            <description>SUBMIT</description>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
    assert_xml_tag(tag: 'review', attributes: { by_project: 'BaseDistro2.0', by_package: 'pack2' })

    # set project to approve it
    login_king
    post '/source/BaseDistro2.0/_attribute', params: "<attributes><attribute namespace='OBS' name='ApprovedRequestSource' /></attributes>"
    assert_response :success

    # create request again
    login_tom
    req = "<request>
            <action type='submit'>
              <source project='BaseDistro2.0' package='pack2' rev='1' />
              <target project='home:tom' package='pack2' />
            </action>
            <description>SUBMIT</description>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })
    assert_no_xml_tag(tag: 'review', attributes: { by_project: 'BaseDistro2.0', by_package: 'pack2' })

    # cleanup attribute
    login_king
    delete '/source/BaseDistro2.0/_attribute/OBS:ApprovedRequestSource'
    assert_response :success
  end

  def test_submit_unchanged_sources
    # create ower playground
    login_king
    put '/source/DummY/_meta', params: "<project name='DummY'><title/><description/><link project='BaseDistro2.0'/></project>"
    assert_response :success

    # branch a package which does not exist in project, but project is linked
    login_tom
    post '/source/DummY/pack2', params: { cmd: :branch }
    assert_response :success

    # check source link
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    ret = Xmlhash.parse @response.body
    assert_equal 'BaseDistro2.0:LinkedUpdateProject', ret['project']
    assert_nil ret['package'] # same package name

    # create request back of unchanged sources, but creating a new package instance
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    req = "<request>
            <action type='submit'>
              <source project='RemoteInstance:home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success

    # now link package inside, so sources are unchanged
    login_king
    post '/source/BaseDistro2.0/pack2', params: { cmd: :branch, target_project: 'DummY' }
    assert_response :success
    login_tom
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_action' })
    req = "<request>
            <action type='submit'>
              <source project='RemoteInstance:home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_action' })

    # create request to a different place works
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='packNew' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    req = "<request>
            <action type='submit'>
              <source project='RemoteInstance:home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='packNew' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success

    # now with modified sources
    login_tom
    put '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/new_file', params: 'just to have changed source'
    assert_response :success
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    req = "<request>
            <action type='submit'>
              <source project='RemoteInstance:home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success

    # cleanup
    login_king
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    delete '/source/DummY'
    assert_response :success
  end

  def test_branch_and_submit_request_to_linked_project_and_delete_it_again
    # create ower playground
    login_king
    put '/source/DummY/_meta', params: "<project name='DummY'><title/><description/><link project='BaseDistro2.0'/></project>"
    assert_response :success

    # branch a package which does not exist in project, but project is linked
    login_tom
    post '/source/DummY/pack2', params: { cmd: :branch }
    assert_response :success

    # check source link
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    ret = Xmlhash.parse @response.body
    assert_equal 'BaseDistro2.0:LinkedUpdateProject', ret['project']
    assert_nil ret['package'] # same package name

    # do some modification
    put '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/NEW_FILE', params: 'content'
    assert_response :success

    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <sourceupdate>noupdate</sourceupdate>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?

    # accept the request
    login_king
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'accepted' })

    get '/source/DummY/pack2/_history'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'comment', content: 'SUBMIT')
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'requestid', content: id)

    # pack2 got created
    get '/source/DummY/pack2/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'BaseDistro2.0', package: nil })

    ### try again with update link
    # do some modification
    put '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/NEW_FILE', params: 'NEW content'
    assert_response :success
    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2' />
              <options>
                <updatelink>true</updatelink>
              </options>
            </action>
            <description>SUBMIT bso#123</description>
            <state who='Iggy' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?

    # ensure that the diff shows the link change
    post "/request/#{id}?cmd=diff&view=xml"
    assert_response :success
    assert_xml_tag(parent: { tag: 'file', attributes: { state: 'changed' } }, tag: 'old', attributes: { name: '_link' })

    # Validate also the issue parsing of the description
    post "/request/#{id}?cmd=diff&view=xml&withdescriptionissues=1"
    assert_response :success
    assert_xml_tag(parent: { tag: 'issues' }, tag: 'issue', attributes: { tracker: 'bso', name: '123' })

    # accept the request
    login_king
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success

    # the link in pack2 got changed
    get '/source/DummY/pack2/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: nil })

    # the diff is still working due to acceptinfo
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(parent: { tag: 'action', attributes: { type: 'submit' } }, tag: 'acceptinfo', attributes: { rev: '3' })
    post "/request/#{id}?cmd=diff"
    assert_response :success
    assert_match 'NEW_FILE', @response.body
    post "/request/#{id}?cmd=diff&view=xml"
    assert_response :success
    assert_xml_tag(parent: { tag: 'file', attributes: { state: 'changed' } }, tag: 'new', attributes: { name: 'NEW_FILE' })

    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:tom:branches:BaseDistro2.0:LinkedUpdateProject' package='pack2' />
              <target project='DummY' package='pack2.NEW' />
              <options>
                <sourceupdate>cleanup</sourceupdate>
                <updatelink>true</updatelink>
              </options>
            </action>
            <description>SUBMIT</description>
            <state who='Iggy' name='new'/>
          </request>"
    post '/request?cmd=create&addrevision=1', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?

    # ensure that the diff shows the link change
    post "/request/#{id}?cmd=diff&view=xml"
    assert_response :success
    assert_xml_tag(parent: { tag: 'file', attributes: { state: 'added' } }, tag: 'new', attributes: { name: '_link' })

    # accept the request
    login_king
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success

    # the link got transfered
    get '/source/DummY/pack2.NEW/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: nil })

    ###
    # create delete request two times
    login_tom
    req = "<request>
            <action type='delete'>
              <target project='DummY' package='pack2'/>
            </action>
            <action type='delete'>
              <target project='DummY' package='pack2.NEW'/>
            </action>
            <description>DELETE REQUEST</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id2 = node['id']
    assert id2.present?
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id3 = node['id']
    assert id3.present?

    # accept the request
    login_king
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'accepted' })

    # validate result
    get '/source/DummY/pack2/_meta'
    assert_response :success
    assert_xml_tag(tag: 'package', attributes: { project: 'BaseDistro2.0', name: 'pack2' })
    get '/source/DummY/pack2/_history?deleted=1'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'comment', content: 'DELETE REQUEST')
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'requestid', content: id)

    login_king
    # you can only accept request in state new
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })

    # you can only accept request in state new and with an existing target
    post "/request/#{id2}?cmd=changestate&newstate=new&force=1"
    assert_response :success
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1"
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'not_existing_target' })

    # decline the request
    post "/request/#{id2}?cmd=changestate&newstate=declined"
    assert_response :success
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })

    # submitter is accepting the decline => revoke
    login_tom
    post "/request/#{id2}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })

    # try to decline it again after revoke
    login_king
    post "/request/#{id2}?cmd=changestate&newstate=declined"
    assert_response :forbidden
    assert_match(/set state to declined from a final state is not allowed./, @response.body)

    # revoke the request
    post "/request/#{id3}?cmd=changestate&newstate=revoked"
    assert_response :success
    get "/request/#{id3}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'revoked' })

    # cleanup
    login_king
    delete '/source/DummY'
    assert_response :success
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
  end

  def test_auto_accept_request
    login_tom

    travel_to(Date.new(2010, 7, 12))

    # create request with auto accept tomorrow
    req = "<request>
            <action type='delete'>
              <target project='home:Iggy' package='TestPack' />
            </action>
            <accept_at>2010-07-13 14:00:21.000000000 Z</accept_at>
            <description>SUBMIT</description>
            <state name='new' />
          </request>"
    post '/request?cmd=create', params: req
    # user has no write permission in target
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })

    # works as user with write permission in target
    login_Iggy
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?
    # and a second request
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id2 = node['id']
    assert id.present?

    # correct rendered
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'accept_at', content: '2010-07-13 14:00:21 UTC')

    # but not when the time is yesterday
    req = "<request>
            <action type='delete'>
              <target project='home:Iggy' package='TestPack' />
            </action>
            <accept_at>2010-07-11 14:00:21.000000000 Z</accept_at>
            <description>SUBMIT</description>
            <state who='tom' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'request_save_error' })
    assert_xml_tag(tag: 'summary', content: 'Auto accept time is in the past')

    # now time travel and accept
    travel(2.days)
    # the backend has to be up before we can accept
    Backend::Test.start
    BsRequest.delayed_auto_accept
    # Run delayed jobs for newly created bs request.
    # NOTE: bs requests are now identified by their number attribute
    BsRequestAutoAcceptJob.new.perform(BsRequest.find_by_number(id).id)
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'accept_at', content: '2010-07-13 14:00:21 UTC')
    assert_xml_tag(tag: 'state', attributes: { name: 'accepted', when: '2010-07-14T00:00:00', who: 'Iggy' })

    # and now check that the package is gone indeed
    get '/source/home:Iggy/TestPack'
    assert_response :not_found

    # the other one got close because the target does not exist anymore
    get "/request/#{id2}"
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'declined', when: '2010-07-14T00:00:00', who: 'Iggy' })
    assert_xml_tag(tag: 'comment', content: "The package 'home:Iggy/TestPack' has been removed")

    # good, now revive to fix the state of the union
    post '/source/home:Iggy/TestPack?cmd=undelete'
    assert_response :success
  end

  def test_set_auto_accept
    login_tom

    travel_to(Date.new(2010, 7, 12))

    req = "<request>
            <action type='delete'>
              <target project='home:Iggy' package='TestPack' />
            </action>
            <description>delete</description>
            <state name='new' />
          </request>"

    # works as user with write permission in target
    login_Iggy
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?

    # accept it now
    post "/request/#{id}?cmd=setacceptat"
    assert_response :success

    # correct rendered
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'accept_at', content: '2010-07-12 00:00:00 UTC')

    # modify accept time
    post "/request/#{id}?cmd=setacceptat&time='2013-12-01%2000:00:00%20UTC'"
    assert_response :success

    # correct rendered
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'accept_at', content: '2013-12-01 00:00:00 UTC')
  end

  def test_branch_version_update_and_submit_request_back
    # branch a package which does not exist in project, but project is linked
    login_tom
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :success

    # version update
    spec = File.read("#{Rails.root}/test/fixtures/backend/source/home:Iggy/TestPack/TestPack.spec")
    spec.gsub!(/^Version:.*/, 'Version: 2.42')
    spec.gsub!(/^Release:.*/, 'Release: 1')
    Backend::Connection.put('/source/home:tom:branches:home:Iggy/TestPack/TestPack.spec?user=king', spec)
    assert_response :success

    get '/source/home:tom:branches:home:Iggy/TestPack?view=info&parse=1'
    assert_response :success
    assert_xml_tag(tag: 'version', content: '2.42')
    assert_xml_tag(tag: 'release', content: '1')

    get '/source/home:tom:branches:home:Iggy/TestPack?expand=1'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
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
            <state name='new' />
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value(:id)

    # decline it and try to accept it
    # must not work to avoid races between multiple users
    login_king
    post "/request/#{id}?cmd=changestate&newstate=declined"
    assert_response :success
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'post_request_no_permission' })
    assert_xml_tag(tag: 'summary', content: 'Request is not in new state. You may reopen it by setting it to new.')
    # reopen and accept the request
    post "/request/#{id}?cmd=changestate&newstate=new"
    assert_response :success
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get '/source/home:Iggy/TestPack?view=info&parse=1'
    assert_response :success
    assert_xml_tag(tag: 'version', content: '2.42')
    assert_xml_tag(tag: 'release', content: '1')

    # vrev must not get smaller after accept
    get '/source/home:tom:branches:home:Iggy/TestPack?expand=1'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    vrev_after_accept = node.value(:vrev)
    assert vrev <= vrev_after_accept

    # cleanup
    delete '/source/home:tom:branches:home:Iggy'
    assert_response :success
    # restore original spec file
    Backend::Connection.put('/source/home:Iggy/TestPack/TestPack.spec?user=king', File.read("#{Rails.root}/test/fixtures/backend/source/home:Iggy/TestPack/TestPack.spec"))
    assert_response :success
  end

  # test permissions on read protected objects
  #
  #
  def test_submit_from_source_protected_project
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    post '/request?cmd=create', params: load_backend_file('request/from_source_protected_valid')
    assert_response :success
    assert_xml_tag(tag: 'request')
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    # show diffs
    post "/request/#{id}?cmd=diff"
    assert_response :success

    # diffs are secret for others
    reset_auth
    post "/request/#{id}?cmd=diff"
    assert_response :unauthorized
    login_Iggy
    post "/request/#{id}?cmd=diff"
    # make sure to always either show a diff or an error - empty diff is not an option
    assert_response :forbidden
  end

  # create requests to hidden from external
  def request_hidden(user, pass, backend_file)
    reset_auth
    req = load_backend_file(backend_file)
    post '/request?cmd=create', params: req
    assert_response :unauthorized
    assert_select 'status[code] > summary', /Authentication required/
    prepare_request_with_user(user, pass)
    post '/request?cmd=create', params: req
  end

  ## create request to hidden package from open place - valid user  - success
  def test_create_request_to_hidden_package_from_open_place_valid_user
    request_hidden('adrian', 'buildservice', 'request/to_hidden_from_open_valid')
    assert_response :success
    # assert_xml_tag( :tag => "state", :attributes => { :name => 'new' } )
  end

  ## create request to hidden package from open place - invalid user - fail
  # request_controller.rb:178
  def test_create_request_to_hidden_package_from_open_place_invalid_user
    request_hidden('Iggy', 'buildservice', 'request/to_hidden_from_open_invalid')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_project' })
  end

  ## create request to hidden package from hidden place - valid user - success
  def test_create_request_to_hidden_package_from_hidden_place_valid_user
    login_king
    put '/source/HiddenProject/target/file', params: 'ASD'
    assert_response :success
    request_hidden('adrian', 'buildservice', 'request/to_hidden_from_hidden_valid')
    assert_response :success
    assert_xml_tag(tag: 'state', attributes: { name: 'new' })
  end

  ## create request to hidden package from hidden place - invalid user - fail
  def test_create_request_to_hidden_package_from_hidden_place_invalid_user
    request_hidden('Iggy', 'buildservice', 'request/to_hidden_from_hidden_invalid')
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_project' })
  end

  # requests from Hidden to external
  ## create request from hidden package to open place - valid user  - fail ! ?
  def test_create_request_from_hidden_package_to_open_place_valid_user
    request_hidden('adrian', 'buildservice', 'request/from_hidden_to_open_valid')
    # FIXME: !!
    # should we really allow this - might be a mistake. qualified procedure could be:
    # sr from hidden to hidden and then make new location visible
    assert_response :success
    # FIXME: implementation unclear
  end

  ### bugowner
  ### role
  def test_hidden_add_role_request
    login_Iggy
    post '/request?cmd=create', params: load_backend_file('request/hidden_add_role_fail')
    # should fail as this user shouldn't see the target package at all.
    assert_response :not_found if @ENABLE_BROKEN_TEST
    reset_auth
    login_adrian
    post '/request?cmd=create', params: load_backend_file('request/hidden_add_role')
    assert_response :success
  end

  # bugreport bnc #674760
  def test_try_to_delete_project_without_permissions
    login_Iggy

    put '/source/home:Iggy:Test/_meta', params: "<project name='home:Iggy:Test'> <title /> <description /> </project>"
    assert_response :success

    # first action is permitted, but second not
    post '/request?cmd=create', params: '<request>
                                   <action type="delete">
                                     <target project="home:Iggy:Test"/>
                                   </action>
                                   <action type="delete">
                                     <target project="kde4"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    # accept this request without permissions
    post "/request/#{id}?cmd=changestate&newstate=accepted&force=1"
    assert_response :forbidden

    # everything still there
    get '/source/home:Iggy:Test/_meta'
    assert_response :success
    get '/source/kde4/_meta'
    assert_response :success

    delete '/source/home:Iggy:Test'
    assert_response :success
  end

  # bugreport bnc #833616
  def test_permission_check_for_package_only_permissions
    login_Iggy

    # validate setup for this check
    get '/source/home:Iggy/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'person', attributes: { userid: 'fred', role: 'maintainer' })
    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    assert_xml_tag(tag: 'person', attributes: { userid: 'fred', role: 'maintainer' })

    # create request for package, which is maintained by fred
    post '/request?cmd=create', params: '<request>
                                   <action type="add_role">
                                     <target project="home:Iggy" package="TestPack"/>
                                     <person name="adrian" role="maintainer"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    # decline as fred
    login_fred
    post "/request/#{id}?cmd=changestate&newstate=declined"
    assert_response :success

    # create request for project, where fred has no permissions
    login_Iggy
    post '/request?cmd=create', params: '<request>
                                   <action type="add_role">
                                     <target project="home:Iggy" />
                                     <person name="adrian" role="maintainer"/>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node.value('id')

    # decline as fred
    login_fred
    post "/request/#{id}?cmd=changestate&newstate=declined"
    assert_response :forbidden
  end

  def test_invalid_names
    login_Iggy

    req = "<request>
            <action type='submit'>
              <source project='kde4' package='kdelibs' />
              <target project='c++ ' package='TestPack'/>
            </action>
            <description/>
            <state who='Iggy' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'invalid_record' })

    req = "<request>
            <action type='submit'>
              <source project='kde4' package='kdelibs' />
              <target project='c++' package='TestPack '/>
            </action>
            <description/>
            <state who='Iggy' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'invalid_record' })
  end

  def test_invalid_cleanup_use
    login_Iggy

    req = "<request>
            <action type='submit'>
              <source project='home:Iggy' package='TestPack' rev='0' />
              <target project='home:Iggy' package='TestPack' />
              <options>
                <sourceupdate>cleanup</sourceupdate>
              </options>
            </action>
            <description/>
            <state who='Iggy' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_xml_tag(tag: 'status', attributes: { code: 'invalid_record' })
  end

  def test_special_chars
    login_Iggy
    # create request
    req = "<request>
            <action type='submit'>
              <source project='home:Iggy' package='TestPack' />
              <target project='c++' package='TestPack'/>
            </action>
            <description/>
            <state who='Iggy' name='new'/>
          </request>"
    post '/request?cmd=create', params: req
    assert_response :success

    node = Xmlhash.parse(@response.body)
    id = node.value :id
    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'c++', package: 'TestPack' })

    get '/request?view=collection&user=Iggy&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'target', attributes: { project: 'c++', package: 'TestPack' })

    get '/request?view=collection&project=c%2b%2b&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'target', attributes: { project: 'c++', package: 'TestPack' })

    get '/request?view=collection&project=c%2b%2b&package=TestPack&states=new,review'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'target', attributes: { project: 'c++', package: 'TestPack' })
  end

  def test_project_delete_request_with_pending
    # try to replay rq 74774
    login_Iggy
    meta = "<project name='home:Iggy:todo'><title></title><description/><repository name='base'>
      <path repository='BaseDistroUpdateProject_repo' project='BaseDistro:Update'/>
        <arch>i586</arch>
        <arch>x86_64</arch>
     </repository>
     </project>"

    put url_for(controller: :source_project_meta, action: :update, project: 'home:Iggy:todo'), params: meta
    assert_response :success

    meta = "<package name='realfun' project='home:Iggy:todo'><title/><description/></package>"
    put url_for(controller: :source_package_meta, action: :update, project: 'home:Iggy:todo', package: 'realfun'), params: meta
    assert_response :success

    login_tom
    post '/source/home:Iggy:todo/realfun', params: { cmd: 'branch' }
    assert_response :success

    # verify
    get '/source/home:tom:branches:home:Iggy:todo/realfun/_meta'
    assert_response :success

    # now try to delete the original project
    # and create a delete request
    rq = '<request>
           <action type="delete">
             <target project="home:Iggy:todo"/>
           </action>
           <state name="new" />
         </request>'

    post '/request?cmd=create', params: rq
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    iddelete = node.value('id')

    login_Iggy
    post "/request/#{iddelete}?cmd=changestate&newstate=accepted"
    assert_response :success

    # verify request number loging
    login_king
    get '/source/home:Iggy:todo/_project/_history?meta=1&deleted=1'
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'requestid', content: iddelete)
    assert_response :success

    # cleanup
    delete '/source/home:Iggy:todo'
    assert_response :not_found # already removed
    login_tom
    delete '/source/home:tom:branches:home:Iggy:todo'
    assert_response :success
  end

  def test_try_to_modify_virtual_package
    login_Iggy

    get '/source/BaseDistro:Update/pack1/_meta'
    assert_response :success
    assert_xml_tag(tag: 'package', attributes: { project: 'BaseDistro' }) # it appears via project link

    # and create a request to wrong target
    %w[delete set_bugowner add_role change_devel].each do |at|
      rq = '<request>
             <action type="' + at + '">'
      rq += "  <source project='BaseDistro' package='pack1'/>" if at == 'change_devel'
      rq += '  <target project="BaseDistro:Update" package="pack1"/>'
      rq += "  <person name='Iggy' role='reviewer' />" if at == 'add_role'
      rq += '</action>
             <state name="new" />
           </request>'

      post '/request?cmd=create', params: rq
      assert_response :not_found
      assert_xml_tag(tag: 'status', attributes: { code: 'not_found' })
    end
  end

  def test_repository_delete_request
    login_Iggy
    meta = "<project name='home:Iggy:todo'><title></title><description/><repository name='base'>
      <path repository='BaseDistroUpdateProject_repo' project='BaseDistro:Update'/>
        <arch>i586</arch>
        <arch>x86_64</arch>
     </repository>
     </project>"

    put url_for(controller: :source_project_meta, action: :update, project: 'home:Iggy:todo'), params: meta
    assert_response :success

    meta = "<package name='realfun' project='home:Iggy:todo'><title/><description/></package>"
    put url_for(controller: :source_package_meta, action: :update, project: 'home:Iggy:todo', package: 'realfun'), params: meta
    assert_response :success

    login_tom
    post '/source/home:Iggy:todo/realfun', params: { cmd: 'branch' }
    assert_response :success

    # verify
    get '/source/home:tom:branches:home:Iggy:todo/realfun/_meta'
    assert_response :success

    # delete repository via request
    rq = '<request>
           <action type="delete">
             <target project="home:Iggy:todo" repository="base"/>
           </action>
           <state name="new" />
         </request>'

    post '/request?cmd=create', params: rq
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    iddelete = node.value('id')
    post '/request?cmd=create', params: rq
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    iddelete2 = node.value('id')

    login_Iggy
    post "/request/#{iddelete}?cmd=changestate&newstate=accepted"
    assert_response :success

    # verify
    get '/source/home:Iggy:todo/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'repository', attributes: { name: 'base' }
    get '/source/home:tom:branches:home:Iggy:todo/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'base' } },
                   tag: 'path', attributes: { project: 'deleted', repository: 'deleted' }

    # try again and fail
    login_Iggy
    post "/request/#{iddelete2}?cmd=changestate&newstate=accepted"
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'repository_missing' })

    # cleanup
    delete '/source/home:Iggy:todo'
    assert_response :success
    login_tom
    delete '/source/home:tom:branches:home:Iggy:todo'
    assert_response :success
  end

  def test_delete_request_id
    login_tom
    req = load_backend_file('request/1')
    post '/request?cmd=create', params: req
    assert_response :success

    node = Xmlhash.parse(@response.body)
    id = node['id']
    get "/request/#{id}"
    assert_response :success

    # old admins can do that
    delete "/request/#{id}"
    assert_response :forbidden
    assert_xml_tag tag: 'summary', content: 'Requires admin privileges'

    login_king
    delete "/request/#{id}"
    assert_response :success

    get "/request/#{id}"
    assert_response :not_found
  end

  def test_reopen_declined_request
    login_Iggy
    req = load_backend_file('request/add_role')
    post '/request?cmd=create', params: req
    assert_response :success

    node = Xmlhash.parse(@response.body)
    id = node['id']
    get "/request/#{id}"
    assert_response :success

    login_fred
    post "/request/#{id}?cmd=changestate&newstate=declined&comment=not+you"
    get "/request/#{id}"
    assert_xml_tag(tag: 'state', attributes: { name: 'declined' })

    # fred should be able to reopen
    post "/request/#{id}?cmd=changestate&newstate=new&comment=oh"
    get "/request/#{id}"
    assert_xml_tag(tag: 'state', attributes: { name: 'review' })
  end

  # it was reported that requests can't be revoked - test cases verifie sthat
  def test_revoke_autodeclined_submit_requests
    login_Iggy

    travel_to(Date.new(2010, 7, 12))
    put '/source/home:Iggy:fordecline/_meta', params: "<project name='home:Iggy:fordecline'><title></title><description></description></project>"
    assert_response :success

    post '/request?cmd=create', params: "<request><action type='add_role'><target project='home:Iggy:fordecline'/><person name='Iggy' role='reviewer'/></action></request>"
    assert_response :success
    id = Xmlhash.parse(@response.body)['id']

    travel(1.second)
    delete '/source/home:Iggy:fordecline'
    assert_response :success

    get "/request/#{id}?withhistory=1"
    node = Xmlhash.parse(@response.body)
    assert_equal({ 'id' => id,
                   'creator' => 'Iggy',
                   'action' =>
                                { 'type' => 'add_role',
                                  'target' => { 'project' => 'home:Iggy:fordecline' },
                                  'person' => { 'name' => 'Iggy', 'role' => 'reviewer' } },
                   'state' =>
                                { 'name' => 'declined',
                                  'who' => 'Iggy',
                                  'when' => '2010-07-12T00:00:01',
                                  'created' => '2010-07-12T00:00:00',
                                  'comment' => "The target project 'home:Iggy:fordecline' has been removed" },
                   'history' => [{ 'who' => 'Iggy',
                                   'when' => '2010-07-12T00:00:00',
                                   'description' => 'Request created' },
                                 { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:01',
                                   'description' => 'Request got declined',
                                   'comment' => "The target project 'home:Iggy:fordecline' has been removed" }] }, node)

    travel(1.second)
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success

    get "/request/#{id}?withhistory=1"
    node = Xmlhash.parse(@response.body)
    assert_equal({ 'id' => id,
                   'creator' => 'Iggy',
                   'action' =>
                                { 'type' => 'add_role',
                                  'target' => { 'project' => 'home:Iggy:fordecline' },
                                  'person' => { 'name' => 'Iggy', 'role' => 'reviewer' } },
                   'state' => { 'name' => 'revoked',
                                'who' => 'Iggy',
                                'when' => '2010-07-12T00:00:02',
                                'created' => '2010-07-12T00:00:00',
                                'comment' => {} },
                   'history' =>
                                [{ 'who' => 'Iggy', 'when' => '2010-07-12T00:00:00',
                                   'description' => 'Request created' },
                                 { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:01',
                                   'description' => 'Request got declined',
                                   'comment' => "The target project 'home:Iggy:fordecline' has been removed" },
                                 { 'who' => 'Iggy', 'when' => '2010-07-12T00:00:02',
                                   'description' => 'Request got revoked' }] }, node)
  end

  def test_check_target_maintainer
    login_tom
    post '/request?cmd=create', params: "<request><action type='submit'><source project='Apache' package='apache2'/><target project='kde4' package='apache2'/></action></request>"
    assert_response :success
    id = Xmlhash.parse(@response.body)['id']

    assert_not BsRequest.find_by_number(id).target_maintainer?(User.session), 'tom is not target maintainer'
  end

  def test_cleanup_from_home
    login_dmayr
    req = load_backend_file('request/cleanup_from_home')
    post '/request?cmd=create', params: req
    assert_response :success
    id = Xmlhash.parse(@response.body)['id']

    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    # now check that the package was deleted, but not the project
    get '/source/home:dmayr'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'x11vnc' }

    delete '/source/home:Iggy/x11vnc'
    assert_response :success
  end

  def test_reviews_in_delete_requests
    # make Iggy maintainer for pack2 in this test
    packages(:Devel_BaseDistro_Update_pack2).relationships.create(role: roles(:maintainer), user: users(:Iggy))

    login_tom
    post '/request?cmd=create', params: "<request><action type='delete'><target project='Devel:BaseDistro:Update' package='pack2'/></action></request>"
    assert_response :success
    id = Xmlhash.parse(@response.body)['id']

    # Iggy can't accept due to devel package
    login_Iggy
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :bad_request
    assert_xml_tag tag: 'summary', content: 'Package is used by following packages as devel package: BaseDistro:Update/pack2'

    # but they should be able to add reviewers
    post "/request/#{id}?cmd=addreview&by_user=tom"
    assert_response :success

    # now tom should be able to accept the review
    login_tom
    post "/request/#{id}?cmd=changereviewstate&by_user=tom&newstate=accepted"
    assert_response :success
  end

  def cleanup_empty_projects_helper(expect_cleanup_empty_project)
    sprj = 'Apache'
    bprj = "home:king:branches:#{sprj}"

    post "/source/#{sprj}/apache2", params: { cmd: :branch, target_project: bprj }
    assert_response :success
    put "/source/#{bprj}/apache2/dummy", params: 'dummy'
    assert_response :success

    post "/source/#{sprj}/Tidy", params: { cmd: :branch, target_project: bprj }
    assert_response :success
    put "/source/#{bprj}/Tidy/dummy", params: 'dummy'
    assert_response :success

    # Submit apache2 back. It is not the last project.
    post '/request?cmd=create', params: "<request><action type='submit'><source project='#{bprj}' package='apache2'/><target project='#{sprj}' package='apache2'/></action></request>"
    assert_response :success
    # Accept our own request :-)
    id = Xmlhash.parse(@response.body)['id']
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success
    # apache2 has gone, but the project remains
    get "/source/#{bprj}"
    assert_response :success
    assert_no_xml_tag tag: 'entry', attributes: { name: 'apache2' }
    assert_xml_tag tag: 'entry', attributes: { name: 'Tidy' }

    # Submit Tidy back. It *is* the last project.
    post '/request?cmd=create', params: "<request><action type='submit'><source project='#{bprj}' package='Tidy'/><target project='#{sprj}' package='Tidy'/></action></request>"
    assert_response :success
    id = Xmlhash.parse(@response.body)['id']
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success
    get "/source/#{bprj}"
    if expect_cleanup_empty_project
      assert_response :not_found
    else
      assert_response :success
      assert_no_xml_tag tag: 'entry', attributes: { name: 'apache2' }
      assert_no_xml_tag tag: 'entry', attributes: { name: 'Tidy' }
    end

    delete "/source/#{sprj}/Tidy/dummy", params: 'dummy'
    assert_response :success
    delete "/source/#{sprj}/apache2/dummy", params: 'dummy'
    assert_response :success
  end

  def test_cleanup_empty_projects
    # we use an admin user so we can twiddle the configuration
    login_king

    # By default, OBS expects to have thousands of users, so succesfully
    # submitting the last package in a project cleans up the project to
    # save resources.
    cleanup_empty_projects_helper(true)

    # "small team" mode: resources are unconstrained so we're willing to
    # preserve everyone's project configuration even if the project is empty
    put '/configuration?cleanup_empty_projects=off'
    assert_response :success
    cleanup_empty_projects_helper(false)

    # explicitly go back to the default and check that the result is still
    # the same
    put '/configuration?cleanup_empty_projects=on'
    assert_response :success
    cleanup_empty_projects_helper(true)
  end

  def test_ordering_of_requests
    prepare_request_with_user('Iggy', 'buildservice')

    travel_to(Date.new(2010, 7, 12))
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="default"/>
                                   </action>
                                   <description></description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    default = node['id']
    assert default.present?
    travel(1.second)
    # a second default
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="moderate"/>
                                   </action>
                                   <priority>moderate</priority>
                                   <description></description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    moderate = node['id']
    assert moderate.present?
    travel(1.second)
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro" package="pack2"/>
                                     <target project="home:Iggy" package="low"/>
                                   </action>
                                   <priority>low</priority>
                                   <description></description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    low = node['id']
    assert low.present?
    travel(1.second)
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro:Update" package="pack2"/>
                                     <target project="home:Iggy" package="critical"/>
                                   </action>
                                   <priority>critical</priority>
                                   <description></description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    critical = node['id']
    assert critical.present?
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro2.0" package="pack2"/>
                                     <target project="home:Iggy" package="important"/>
                                   </action>
                                   <priority>important</priority>
                                   <description></description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    important = node['id']
    assert important.present?
    travel(1.second)

    get '/search/request', params: { match: "target/@project = 'home:Iggy'" }
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' },
                   attributes: { matches: 6 })
    node = Xmlhash.parse(@response.body)
    assert_equal node['request'][0]['priority'], 'critical'
    assert_equal node['request'][1]['priority'], 'important'
    # three "moderate" requests, not showing a priority field
    assert_equal node['request'][5]['priority'], 'low'

    # now re-priorize via incident attribute
    login_king
    post '/source/BaseDistro2.0/_attribute', params: "<attributes><attribute namespace='OBS' name='IncidentPriority' >
              <value>100</value>
            </attribute></attributes>"
    assert_response :success
    get '/search/request', params: { match: "target/@project = 'home:Iggy'" }
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' },
                   attributes: { matches: 6 })
    node = Xmlhash.parse(@response.body)
    assert_equal 'important', node['request'][0]['priority']

    # make the low and important request equal high prio
    post '/source/BaseDistro/_attribute', params: "<attributes><attribute namespace='OBS' name='IncidentPriority' >
              <value>100</value>
            </attribute></attributes>"
    assert_response :success
    get '/search/request', params: { match: "target/@project = 'home:Iggy'" }
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' },
                   attributes: { matches: 6 })
    node = Xmlhash.parse(@response.body)
    # they are equal, so important wins
    assert_equal 'important', node['request'][0]['priority']
    assert_equal 'low', node['request'][1]['priority']

    # make the low most important
    post '/source/BaseDistro/_attribute', params: "<attributes><attribute namespace='OBS' name='IncidentPriority' >
              <value>101</value>
            </attribute></attributes>"
    assert_response :success
    get '/search/request', params: { match: "target/@project = 'home:Iggy'" }
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' },
                   attributes: { matches: 6 })
    node = Xmlhash.parse(@response.body)
    assert_equal 'low', node['request'][0]['priority']
    assert_equal 'important', node['request'][1]['priority']
  end
end
