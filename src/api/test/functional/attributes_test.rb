require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class AttributeControllerTest < ActionController::IntegrationTest 
  
  fixtures :all

  def setup
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")

    @controller = SourceController.new
    @controller.start_test_backend

    Suse::Backend.put( '/source/kde4/_meta', DbProject.find_by_name('kde4').to_axml)
    Suse::Backend.put( '/source/kde4/kdelibs/_meta', DbPackage.find_by_name('kdelibs').to_axml)
  end

  def test_index
    ActionController::IntegrationTest::reset_auth
    get "/attribute/"
    assert_response 401

    prepare_request_with_user "tscholz", "asdfasdf" 
    get "/attribute/"
    assert_response :success

    # only one entry ATM - will have to be adopted, lists namespaces
    count = 2
    assert_tag :tag => 'directory', :attributes => { :count => count }
    assert_tag :children => { :count => count }
    assert_tag :child => { :tag => 'entry', :attributes => { :name => "NSTEST" } }
  end

  def test_namespace_index
    prepare_request_with_user "tscholz", "asdfasdf"

    get "/attribute/Redhat"
    assert_response 400

    get "/attribute/OBS"
    assert_response :success
    count = 3
    assert_tag :tag => 'directory', :attributes => { :count => count }
    assert_tag :children => { :count => count }
    assert_tag :child => { :tag => 'entry', :attributes => { :name => "Maintained" } }
  end

  def test_namespace_meta
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/attribute/OBS/_meta"
    assert_response :success
    assert_tag :tag => 'namespace', :attributes => { :name => "OBS" }
    assert_tag :child => { :tag => 'modifiable_by', :attributes => { :user => "king" } }
  end

  def test_create_attributes_project
    data = "<attributes><attribute namespace='OBS' name='Playground'/></attributes>"
    prepare_request_with_user "tom", "thunder"
    post "/source/home:tom/_attribute", data
    assert_response 404
    assert_select "status[code] > summary", /unknown attribute type 'OBS:Playground'/ 

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute></attributes>"
    post "/source/home:tom/_attribute", data
    assert_response 403
    assert_select "status[code] > summary", /Attribute: 'OBS:Maintained' has 1 values, but only 0 are allowed/
  
    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post "/source/home:tom/_attribute", data
    assert_response :success
    post "/source/home:tom/_attribute/OBS:Maintained", data
    assert_response :success

    get "/source/home:tom/_attribute"
    assert_response :success
    get "/source/home:tom/_attribute/OBS:Maintained"
    assert_response :success

    get "/source/NOT_EXISTING/_attribute"
    assert_response 404
    get "/source/home:tom/_attribute/OBS:NotExisting"
    assert_response 403
    get "/source/home:tom/_attribute/NotExisting:NotExisting"
    assert_response 403
  end

  def test_create_attributes_package
    data = "<attributes><attribute namespace='OBS' name='Playground'/></attributes>"
    prepare_request_with_user "fred", "geröllheimer"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 404
    assert_select "status[code] > summary", /unknown attribute type 'OBS:Playground'/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <BROKEN>
            </attribute></attributes>"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 400
    assert_select "status[code] > summary", /Invalid XML/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute></attributes>"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 403
    assert_select "status[code] > summary", /Attribute: 'OBS:Maintained' has 1 values, but only 0 are allowed/

    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response :success
    post "/source/kde4/kdelibs/_attribute/OBS:Maintained", data
    assert_response :success
    post "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained", data
    assert_response :success

    get "/source/kde4/kdelibs/_attribute"
    assert_response :success
    get "/source/kde4/kdelibs/_attribute/OBS:Maintained"
    assert_response :success
    get "/source/kde4/kdelibs/kdelibs-devel/_attribute"
    assert_response :success
    get "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained"
    assert_response :success

    get "/source/kde4/NOT_EXISTING/_attribute"
    assert_response 404
  end

end

