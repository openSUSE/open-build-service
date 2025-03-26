require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class AttributeControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_index
    get '/attribute/'
    assert_response :unauthorized

    login_Iggy
    get '/attribute/'
    assert_response :success

    # only one entry ATM - will have to be adopted, lists namespaces
    count = 2
    assert_xml_tag tag: 'directory', attributes: { count: count }
    assert_xml_tag children: { count: count }
    assert_xml_tag child: { tag: 'entry', attributes: { name: 'NSTEST' } }
  end

  def test_namespace_index
    login_Iggy

    get '/attribute/NotExisting'
    assert_response :not_found

    get '/attribute/OBS'
    assert_response :success
    count = 25
    assert_xml_tag tag: 'directory', attributes: { count: count }
    assert_xml_tag children: { count: count }
    assert_xml_tag child: { tag: 'entry', attributes: { name: 'Maintained' } }
  end

  def test_namespace_meta
    login_Iggy
    get '/attribute/OBS/UpdateProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'definition', attributes: { name: 'UpdateProject', namespace: 'OBS' }
    assert_xml_tag child: { tag: 'modifiable_by', attributes: { user: 'maintenance_coord' } }
    assert_xml_tag child: { tag: 'count', content: '1' }
    assert_xml_tag child: { tag: 'description', content: 'Project is frozen and updates are released via the other project' }
  end

  def test_create_namespace_old
    data = "<namespace name='TEST'><modifiable_by user='adrian'/></namespace>"

    login_Iggy
    post '/attribute/TEST/_meta', params: data
    assert_response :forbidden
    assert_match(/Requires admin privileges/, @response.body)

    delete '/attribute/OBS/_meta'
    assert_response :forbidden
    assert_match(/Requires admin privileges/, @response.body)

    login_king
    # FIXME3.0: POST is deprecated, use PUT
    post '/attribute/TEST/_meta', params: data
    assert_response :success
    get '/attribute/TEST/_meta'
    assert_response :success
    delete '/attribute/TEST/_meta'
    assert_response :success
    get '/attribute/TEST/_meta'
    assert_response :not_found

    # using PUT and new delete route
    put '/attribute/TEST/_meta', params: data
    assert_response :success
    get '/attribute/TEST/_meta'
    assert_response :success
    delete '/attribute/TEST'
    assert_response :success
    get '/attribute/TEST/_meta'
    assert_response :not_found
  end

  def test_create_type
    # create test namespace
    login_king
    data = "<namespace name='TEST'><modifiable_by user='adrian'/></namespace>"
    post '/attribute/TEST/_meta', params: data
    assert_response :success

    reset_auth
    data = "<definition namespace='TEST' name='Dummy'>
              <count>2</count>
              <default>
                <value>A</value>
                <value>B</value>
              </default>
              <allowed>
                <value>A</value>
                <value>B</value>
                <value>C</value>
              </allowed>
              <modifiable_by user='adrian'/>
              <modifiable_by group='test_group'/>
              <modifiable_by role='maintainer'/>
            </definition>"

    post '/attribute/TEST/Dummy/_meta', params: data
    assert_response :unauthorized

    login_adrian
    # FIXME3.0: POST is deprecated, use PUT
    post '/attribute/TEST/Dummy/_meta', params: data
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :success
    delete '/attribute/TEST/Dummy/_meta'
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :not_found

    # new PUT way
    put '/attribute/TEST/Dummy/_meta', params: data
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :success
    # use it
    attrib_data = "<attributes>
                     <attribute namespace='TEST' name='Dummy' >
                       <value>M</value>
                       <value>A</value>
                     </attribute>
                   </attributes>"
    post '/source/home:adrian/_attribute', params: attrib_data
    assert_response :bad_request
    assert_match(/Values Value ('|")M('|") is not allowed./, @response.body)
    get '/source/home:adrian/_attribute'
    assert_response :success
    attrib_data = "<attributes>
                     <attribute namespace='TEST' name='Dummy' >
                       <value>A</value>
                       <value>B</value>
                     </attribute>
                   </attributes>"
    post '/source/home:adrian/_attribute', params: attrib_data

    assert_response :success
    get '/source/home:adrian/_attribute'
    assert_response :success
    assert_xml_tag tag: 'value', content: 'A'
    assert_xml_tag tag: 'value', content: 'B'
    # blame view is working
    get '/source/home:adrian/_project/_attribute?view=blame&meta=1'
    assert_response :success
    assert_match(/^   . \(adrian/, @response.body)

    # cleanup
    login_Iggy
    delete '/attribute/TEST/Dummy/_meta'
    assert_response :forbidden
    login_adrian
    delete '/attribute/TEST/Dummy'
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :not_found
  end

  def test_create_type_via_group
    # create test namespace
    login_king
    data = "<namespace name='TEST'><modifiable_by group='test_group'/></namespace>"
    login_king
    post '/attribute/TEST/_meta', params: data
    assert_response :success

    reset_auth
    data = "<definition name='Dummy' namespace='TEST'>
              <description>Long
desc
ription</description>
              <count>2</count>
              <default>
                <value>A</value>
                <value>B</value>
              </default>
              <allowed>
                <value>A</value>
                <value>B</value>
                <value>C</value>
              </allowed>
              <modifiable_by role='maintainer'/>
              <modifiable_by group='test_group'/>
              <modifiable_by user='adrian'/>
            </definition>"

    post '/attribute/TEST/Dummy/_meta', params: data
    assert_response :unauthorized

    login_adrian
    post '/attribute/TEST/Dummy/_meta', params: data
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :success
    %w[count description default allowed count modifiable_by].each do |i|
      assert_equal(Xmlhash.parse(data)[i], Xmlhash.parse(@response.body)[i])
    end
    login_Iggy
    delete '/attribute/TEST/Dummy/_meta'
    assert_response :forbidden
    login_adrian
    delete '/attribute/TEST/Dummy/_meta'
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :not_found
  end

  def test_with_issue
    # create test namespace
    login_king
    data = "<namespace name='TEST'><modifiable_by user='adrian'/></namespace>"
    login_king
    post '/attribute/TEST/_meta', params: data
    assert_response :success

    reset_auth
    data = "<definition namespace='TEST' name='Dummy'>
              <issue_list/>
            </definition>"

    login_adrian
    post '/attribute/TEST/Dummy/_meta', params: data
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :success

    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi').to_timeout

    # set issues
    data = "<attributes><attribute namespace='TEST' name='Dummy'>
              <issue name='123' tracker='bnc'/>
              <issue name='456' tracker='bnc'/>
            </attribute></attributes>"
    post '/source/home:adrian/_attribute', params: data
    assert_response :success

    get '/source/home:adrian/_attribute/TEST:Dummy'
    assert_response :success
    assert_xml_tag parent: { tag: 'attribute', attributes: { name: 'Dummy', namespace: 'TEST' } },
                   tag: 'issue', attributes: { name: '123', tracker: 'bnc' }
    assert_xml_tag parent: { tag: 'attribute', attributes: { name: 'Dummy', namespace: 'TEST' } },
                   tag: 'issue', attributes: { name: '456', tracker: 'bnc' }

    # remove one
    data = "<attributes><attribute namespace='TEST' name='Dummy'>
              <issue name='456' tracker='bnc'/>
            </attribute></attributes>"
    post '/source/home:adrian/_attribute', params: data
    assert_response :success
    get '/source/home:adrian/_attribute/TEST:Dummy'
    assert_response :success
    assert_no_xml_tag parent: { tag: 'attribute', attributes: { name: 'Dummy', namespace: 'TEST' } },
                      tag: 'issue', attributes: { name: '123', tracker: 'bnc' }
    assert_xml_tag parent: { tag: 'attribute', attributes: { name: 'Dummy', namespace: 'TEST' } },
                   tag: 'issue', attributes: { name: '456', tracker: 'bnc' }

    # cleanup
    delete '/attribute/TEST/Dummy/_meta'
    assert_response :success
    get '/attribute/TEST/Dummy/_meta'
    assert_response :not_found
  end

  def test_attrib_type_meta
    login_Iggy

    get '/attribute/OBS'
    assert_response :success
    count = 25
    assert_xml_tag tag: 'directory', attributes: { count: count }
    assert_xml_tag children: { count: count }
    assert_xml_tag child: { tag: 'entry', attributes: { name: 'Maintained' } }
  end

  def test_invalid_get
    login_Iggy
    get '/source/RemoteInstance:BaseDistro/pack1/_attribute'
    assert_response :not_found
  end

  def test_attrib_write_permissions
    login_tom

    data = "<attributes><attribute namespace='OBS' name='VeryImportantProject'/></attributes>"

    # XML with an attribute I should not be able to create
    post '/source/home:tom/_attribute', params: data
    assert_response :forbidden
    # same with attribute parameter
    post '/source/home:tom/_attribute/OBS:Issues', params: data
    assert_response :forbidden
  end

  def test_attrib_delete_permissions
    # create an admin only attribute
    login_king
    data = "<attributes><attribute namespace='OBS' name='VeryImportantProject'/></attributes>"
    post '/source/home:tom/_attribute', params: data
    assert_response :success

    login_tom
    delete '/source/home:tom/_attribute/OBS:VeryImportantProject'
    assert_response :forbidden
  end

  def test_create_attributes_project
    login_tom

    data = "<attributes><attribute namespace='OBS' name='Playground'/></attributes>"
    post '/source/home:tom/_attribute', params: data
    assert_response :not_found
    assert_select 'status[code] > summary', /Attribute Type OBS:Playground does not exist/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute></attributes>"
    post '/source/home:tom/_attribute', params: data
    assert_response :bad_request
    assert_select 'status[code] > summary', /has 1 values, but only 0 are allowed/

    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post '/source/home:tom/_attribute', params: data
    assert_response :success
    post '/source/home:tom/_attribute/OBS:Maintained', params: data
    assert_response :success

    get '/source/home:tom/_attribute'
    assert_response :success
    get '/source/home:tom/_attribute/OBS:Maintained'
    assert_response :success
    assert_equal({ 'attribute' => { 'name' => 'Maintained', 'namespace' => 'OBS' } }, Xmlhash.parse(@response.body))

    get '/source/NOT_EXISTING/_attribute'
    assert_response :not_found
    get '/source/home:tom/_attribute/OBS:NotExisting'
    assert_response :not_found
    get '/source/home:tom/_attribute/NotExisting:NotExisting'
    assert_response :not_found

    # via remote link
    get '/source/RemoteInstance:home:tom/_attribute/OBS:Maintained'
    assert_response :not_implemented

    # via group
    login_adrian
    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post '/source/home:tom/_attribute', params: data
    assert_response :success

    # as admin
    login_king
    post '/source/home:tom/_attribute', params: data
    assert_response :success

    # not allowed
    login_Iggy
    post '/source/home:tom/_attribute', params: data
    assert_response :forbidden
    delete '/source/home:tom/_attribute/OBS:Maintained'
    assert_response :forbidden
    get '/source/home:tom/_attribute/OBS:Maintained'
    assert_response :success

    # check history
    get '/source/home:tom/_project?meta=1'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: '_attribute' }
    get '/source/home:tom/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    revision = Xmlhash.parse(@response.body).elements('revision').last
    assert_equal 'king', revision['user']
    srcmd5 = revision['srcmd5']

    # check history on changed value only
    login_king
    screenshot = "<attributes><attribute namespace='OBS' name='ScreenShots'><value>ftp://...</value></attribute></attributes>"
    post '/source/home:tom/_attribute', params: screenshot
    assert_response :success
    get '/source/home:tom/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    revision = Xmlhash.parse(@response.body).elements('revision').last
    assert_equal 'king', revision['user']
    rev_nr = revision['rev'].to_i
    screenshot = "<attributes><attribute namespace='OBS' name='ScreenShots'><value>http://...</value></attribute></attributes>"
    post '/source/home:tom/_attribute', params: screenshot
    assert_response :success
    get '/source/home:tom/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    revision = Xmlhash.parse(@response.body).elements('revision').last
    assert_equal (rev_nr + 1), revision['rev'].to_i

    # delete
    login_tom
    post '/source/home:tom/_attribute', params: data
    assert_response :success
    delete '/source/home:tom/_attribute/OBS:Maintained'
    assert_response :success
    delete '/source/home:tom/_attribute/OBS:Maintained'
    assert_response :not_found

    # get old revision
    # both ways need to work, first one for backward compatibility
    get "/source/home:tom/_attribute?rev=#{srcmd5}"
    assert_response :success
    assert_xml_tag(tag: 'attribute', attributes: { namespace: 'OBS', name: 'Maintained' })
    get "/source/home:tom/_project/_attribute?meta=1&rev=#{srcmd5}"
    assert_response :success
    assert_xml_tag(tag: 'attribute', attributes: { namespace: 'OBS', name: 'Maintained' })

    # get current
    get '/source/home:tom/_attribute/OBS:Maintained'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['attribute'].nil?
  end

  def test_create_attributes_package
    login_fred

    data = "<attributes><attribute namespace='OBS' name='Playground'/></attributes>"
    post '/source/kde4/kdelibs/_attribute', params: data
    assert_response :not_found
    assert_select 'status[code] > summary', /Attribute Type OBS:Playground does not exist/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <BROKENXML>
            </attribute></attributes>"
    post '/source/kde4/kdelibs/_attribute', params: data
    assert_response :bad_request
    assert_select 'status[code] > summary', /Invalid XML/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute></attributes>"
    post '/source/kde4/kdelibs/_attribute', params: data
    assert_response :bad_request
    assert_select 'status[code] > summary', /has 1 values, but only 0 are allowed/

    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post '/source/kde4/kdelibs/_attribute', params: data
    assert_response :success
    post '/source/kde4/kdelibs/_attribute/OBS:Maintained', params: data
    assert_response :success
    post '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained', params: data
    assert_response :success

    get '/source/kde4/kdelibs/_attribute'
    assert_response :success
    get '/source/kde4/kdelibs/_attribute/OBS:Maintained'
    assert_response :success
    assert_equal({ 'attribute' => [{ 'name' => 'Maintained', 'namespace' => 'OBS' },
                                   { 'name' => 'Maintained', 'namespace' => 'OBS', 'binary' => 'kdelibs-devel' }] },
                 Xmlhash.parse(@response.body))
    get '/source/kde4/kdelibs/kdelibs-devel/_attribute'
    assert_response :success
    get '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained'
    assert_response :success
    assert_equal({ 'attribute' => { 'name' => 'Maintained', 'namespace' => 'OBS', 'binary' => 'kdelibs-devel' } }, Xmlhash.parse(@response.body))

    get '/source/kde4/NOT_EXISTING/_attribute'
    assert_response :not_found

    # no permission check
    login_Iggy
    post '/source/kde4/kdelibs/_attribute', params: data
    assert_response :forbidden
    post '/source/kde4/kdelibs/_attribute/OBS:Maintained', params: data
    assert_response :forbidden
    post '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained', params: data
    assert_response :forbidden
    delete '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained'
    assert_response :forbidden
    get '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained'
    assert_response :success
    delete '/source/kde4/kdelibs/_attribute/OBS:Maintained'
    assert_response :forbidden
    get '/source/kde4/kdelibs/_attribute/OBS:Maintained'
    assert_response :success

    # invalid operations
    delete '/source/kde4/kdelibs/kdelibs-devel/_attribute'
    assert_response :not_found
    delete '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS_Maintained'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_attribute' }

    # check history
    get '/source/kde4/kdelibs?meta=1'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: '_attribute' }
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    revision = Xmlhash.parse(@response.body)['revision'].last
    assert_equal 'fred', revision['user']
    srcmd5 = revision['srcmd5']

    # delete
    reset_auth
    login_fred
    post '/source/kde4/kdelibs/_attribute', params: data
    assert_response :success
    post '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained', params: data
    assert_response :success
    delete '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained'
    assert_response :success
    get '/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained'
    assert_response :success
    delete '/source/kde4/kdelibs/_attribute/OBS:Maintained'
    assert_response :success
    get '/source/kde4/kdelibs/_attribute/OBS:Maintained'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['attribute'].nil?

    # get old revision
    get "/source/kde4/kdelibs/_attribute?meta=1&rev=#{srcmd5}"
    assert_response :success
    assert_xml_tag(tag: 'attribute', attributes: { namespace: 'OBS', name: 'Maintained' })
    assert_xml_tag(tag: 'attribute', attributes: { namespace: 'OBS', name: 'Maintained', binary: 'kdelibs-devel' })
  end

  # FIXME: value based test are missing
end
