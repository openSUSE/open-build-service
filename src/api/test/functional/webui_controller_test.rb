require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class WebuiControllerTest < ActionDispatch::IntegrationTest

  def setup
    super
    wait_for_scheduler_start
  end

  def test_project_infos
    get '/webui/projects/home:Iggy/infos'
    assert_response 401

    login_Iggy
    get '/webui/projects/home:Iggy/infos'
    assert_response :success

  end

  def test_remote_projects
    get "/webui/projects/remotes"
    assert_response 401

    login_Iggy
    get "/webui/projects/remotes"
    assert_response :success
    assert_match(/RemoteInstance/, @response.body)
  end

  def test_remote_projects_as_admin
    login_king
    get "/webui/projects/remotes"
    assert_response :success
    assert_match(/RemoteInstance/, @response.body)
    assert_match(/Remoteurl project which is hidden/, @response.body)
  end

  def test_search_owner
    login_king

    get '/webui/owners'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { :code => 'missing_parameter'}

    # must be after first search controller call or backend might not be started on single test case runs
    wait_for_publisher()

    get "/webui/owners?binary='package'"
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { :code => 'attribute_not_set'}

    get "/webui/owners?binary='package'&attribute='OBS:does_not_exist'"
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { :code => 'unknown_attribute_type'}

    post '/source/home:Iggy/_attribute', "<attributes><attribute namespace='OBS' name='OwnerRootProject' /></attributes>"
    assert_response :success

    get '/webui/owners?binary=DOES_NOT_EXIST'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }

    get '/webui/owners?binary=package'
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => 'home:Iggy', :project => 'home:Iggy', :package => 'TestPack'}

    get '/webui/owners?binary=package'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'owner', :attributes => { :rootproject => 'home:Iggy', :project => 'home:Iggy', :package => 'TestPack'} },
                   :tag => 'filter', :content => 'bugowners'
    assert_xml_tag :parent => { :tag => 'owner', :attributes => { :rootproject => 'home:Iggy', :project => 'home:Iggy', :package => 'TestPack'} },
                   :tag => 'filter', :content => 'maintainers'

    # set devel package (this one has another devel package in home:coolo:test)
    pkg = Package.find_by_project_and_name 'home:Iggy', 'TestPack'
    pkg.develpackage = Package.find_by_project_and_name 'kde4', 'kdelibs'
    pkg.save

    # include devel package
    get '/webui/owners?binary=package'
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => 'home:coolo:test'}

    # search again, but ignore devel package
    get '/webui/owners?binary=package&devel=false'
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => 'home:Iggy', :project => 'home:Iggy', :package => 'TestPack'}

    get '/webui/owners?binary=package&limit=-1'
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => 'home:Iggy', :project => 'home:coolo:test'}

    # reset devel package setting again
    pkg.develpackage = nil
    pkg.save
    # cleanup
    delete '/source/home:Iggy/_attribute/OBS:OwnerRootProject'
    assert_response :success
  end

  test 'project status' do
    login_Iggy

    get '/webui/projects/LocalProject/status?limit_to_fails=true&limit_to_old=false&include_versions=true&ignore_pending=false&filter_devel=_all_'
    assert_response :success
  end

  test 'package rdiff' do
    login_Iggy

    get '/webui/projects/BaseDistro2.0/packages/pack2.linked/rdiff?linkrev=&opackage=pack2&oproject=BaseDistro2.0&orev=&rev='
    assert_response 400
    assert_xml_tag tag: 'summary', content: 'Error getting diff: revision is empty'
  end
end
