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

    get "/webui/owner?binary=package"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" } },
                   :tag => "filter", :content => "bugowners"
    assert_xml_tag :parent => { :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" } },
                   :tag => "filter", :content => "maintainers"

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
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:coolo:test" }

    # reset devel package setting again
    pkg.develpackage = nil
    pkg.save
    # cleanup
    delete "/source/home:Iggy/_attribute/OBS:OwnerRootProject"
    assert_response :success
  end

end
