require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class WebuiControllerTest < ActionController::IntegrationTest

  fixtures :all

  def setup
    super
    wait_for_scheduler_start
  end

  def test_project_infos
    get "/webui/project_infos?project=home:Iggy"
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf"
    get "/webui/project_infos?project=home:Iggy"
    assert_response :success

  end

  def test_search_owner
    prepare_request_with_user "king", "sunflower"

    get "/webui/owner"
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { :code => "missing_parameter" }

    # must be after first search controller call or backend might not be started on single test case runs
    wait_for_publisher()

    get "/webui/owner?binary='package'"
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { :code => "attribute_not_set" }

    get "/webui/owner?binary='package'&attribute='OBS:does_not_exist'"
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { :code => "unknown_attribute_type" }

    post "/source/home:Iggy/_attribute", "<attributes><attribute namespace='OBS' name='OwnerRootProject' /></attributes>"
    assert_response :success

    get "/webui/owner?binary=DOES_NOT_EXIST"
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }

    get "/webui/owner?binary=package"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'login', :content => "fred"
    assert_xml_tag :tag => 'email', :content => "fred@feuerstein.de"
    assert_xml_tag :tag => 'realname', :content => "Frederic Feuerstone"

    get "/webui/owner?binary=package"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'login', :content => "fred"
    assert_xml_tag :tag => 'email', :content => "fred@feuerstein.de"
    assert_xml_tag :tag => 'realname', :content => "Frederic Feuerstone"

    # set devel package (this one has another devel package in home:coolo:test)
    pkg = Package.find_by_project_and_name "home:Iggy", "TestPack"
    pkg.develpackage = Package.find_by_project_and_name "kde4", "kdelibs"
    pkg.save

    # include devel package
    get "/webui/owner?binary=package"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }

    # search again, but ignore devel package
    get "/webui/owner?binary=package&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" }

    get "/webui/owner?binary=package&limit=-1"
    assert_response :success
    assert_xml_tag :tag => 'login', :content => "tom"

    # search via project link
    put "/source/TEMPORARY/_meta", "<project name='TEMPORARY'><title/><description/><link project='home:Iggy'/>
                                      <group groupid='test_group' role='maintainer' />
                                      <repository name='standard'>
                                        <path project='home:Iggy' repository='10.2'/>
                                        <arch>i586</arch>
                                      </repository>
                                    </project>"
    assert_response :success

    get "/webui/owner?project=TEMPORARY&binary=package&limit=-1&expand=1"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy" }

    get "/webui/owner?project=TEMPORARY&binary=package&limit=-1&expand=1&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }

    # additional package
    put "/source/TEMPORARY/pack/_meta", "<package name='pack' project='TEMPORARY'><title/><description/><group groupid='test_group' role='bugowner'/></package>"
    assert_response :success
    raw_put '/source/TEMPORARY/pack/package.spec', File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read()
    assert_response :success
    run_scheduler("i586")
    inject_build_job( "TEMPORARY", "pack", "standard", "i586" )
    run_scheduler("i586")
    wait_for_publisher()

    get "/webui/owner?project=TEMPORARY&binary=package&limit=0&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY", :package => "pack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_xml_tag :tag => 'name', :content => "test_group", :parent => { :tag => "group" }

    # reset devel package setting again
    pkg.develpackage = nil
    pkg.save
    # cleanup
    delete "/source/TEMPORARY"
    assert_response :success
    delete "/source/home:Iggy/_attribute/OBS:OwnerRootProject"
    assert_response :success
  end

end
