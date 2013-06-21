# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class AttributeControllerTest < ActionDispatch::IntegrationTest 
  
  fixtures :all

  def test_index
    get "/attribute/"
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf" 
    get "/attribute/"
    assert_response :success

    # only one entry ATM - will have to be adopted, lists namespaces
    count = 2
    assert_xml_tag :tag => 'directory', :attributes => { :count => count }
    assert_xml_tag :children => { :count => count }
    assert_xml_tag :child => { :tag => 'entry', :attributes => { :name => "NSTEST" } }
  end

  def test_namespace_index
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/attribute/NotExisting"
    assert_response 400

    get "/attribute/OBS"
    assert_response :success
    count = 14
    assert_xml_tag :tag => 'directory', :attributes => { :count => count }
    assert_xml_tag :children => { :count => count }
    assert_xml_tag :child => { :tag => 'entry', :attributes => { :name => "Maintained" } }
  end

  def test_namespace_meta
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/attribute/OBS/UpdateProject/_meta"
    assert_response :success
    assert_xml_tag :tag => 'definition', :attributes => { :name => "UpdateProject", :namespace => "OBS" }
    assert_xml_tag :child => { :tag => 'modifiable_by', :attributes => { :user => "maintenance_coord" } }
    assert_xml_tag :child => { :tag => 'count', :content => "1" }
  end

  def test_create_namespace
    data = "<namespace name='TEST'><modifiable_by user='adrian'/></namespace>"

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/attribute/TEST/_meta", data
    assert_response 403
    assert_match(/Namespace changes are only permitted by the administrator/, @response.body)

    delete "/attribute/OBS/_meta"
    assert_response 403
    assert_match(/Namespace changes are only permitted by the administrator/, @response.body)

    prepare_request_with_user "king", "sunflower"
    post "/attribute/TEST/_meta", data
    assert_response :success
    get "/attribute/TEST/_meta"
    assert_response :success
    delete "/attribute/TEST/_meta"
    assert_response :success
    get "/attribute/TEST/_meta"
    assert_response 404
  end

  def test_create_type
    # create test namespace
    prepare_request_with_user "king", "sunflower"
    data = "<namespace name='TEST'><modifiable_by user='adrian'/></namespace>"
    prepare_request_with_user "king", "sunflower"
    post "/attribute/TEST/_meta", data
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

    post "/attribute/TEST/Dummy/_meta", data
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf"
    delete "/attribute/OBS/Maintenance/_meta"
    assert_response 403
    assert_match(/Attribute type changes are not permitted/, @response.body)

    prepare_request_with_user "adrian", "so_alone"
    post "/attribute/TEST/Dummy/_meta", data
    assert_response :success
    get "/attribute/TEST/Dummy/_meta"
    assert_response :success
    delete "/attribute/TEST/Dummy/_meta"
    assert_response :success
    get "/attribute/TEST/Dummy/_meta"
    assert_response 404
  end

  def test_create_type_via_group
    # create test namespace
    prepare_request_with_user "king", "sunflower"
    data = "<namespace name='TEST'><modifiable_by group='test_group'/></namespace>"
    prepare_request_with_user "king", "sunflower"
    post "/attribute/TEST/_meta", data
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

    post "/attribute/TEST/Dummy/_meta", data
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf"
    delete "/attribute/OBS/Maintenance/_meta"
    assert_response 403
    assert_match(/Attribute type changes are not permitted/, @response.body)

    prepare_request_with_user "adrian", "so_alone"
    post "/attribute/TEST/Dummy/_meta", data
    assert_response :success
    get "/attribute/TEST/Dummy/_meta"
    assert_response :success
    delete "/attribute/TEST/Dummy/_meta"
    assert_response :success
    get "/attribute/TEST/Dummy/_meta"
    assert_response 404
  end

  def test_with_issue
    # create test namespace
    prepare_request_with_user "king", "sunflower"
    data = "<namespace name='TEST'><modifiable_by user='adrian'/></namespace>"
    prepare_request_with_user "king", "sunflower"
    post "/attribute/TEST/_meta", data
    assert_response :success

    reset_auth
    data = "<definition namespace='TEST' name='Dummy'>
              <issue_list/>
            </definition>"

    prepare_request_with_user "adrian", "so_alone"
    post "/attribute/TEST/Dummy/_meta", data
    assert_response :success
    get "/attribute/TEST/Dummy/_meta"
    assert_response :success

    # set issues
    data = "<attributes><attribute namespace='TEST' name='Dummy'>
              <issue name='123' tracker='bnc'/> 
              <issue name='456' tracker='bnc'/> 
            </attribute></attributes>"
    post "/source/home:adrian/_attribute", data
    assert_response :success

    get "/source/home:adrian/_attribute/TEST:Dummy"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'attribute', :attributes => { :name => "Dummy", :namespace => "TEST" } },
                   :tag => 'issue', :attributes => { :name => "123", :tracker => "bnc" }
    assert_xml_tag :parent => { :tag => 'attribute', :attributes => { :name => "Dummy", :namespace => "TEST" } },
                   :tag => 'issue', :attributes => { :name => "456", :tracker => "bnc" }

    # remove one
    data = "<attributes><attribute namespace='TEST' name='Dummy'>
              <issue name='456' tracker='bnc'/> 
            </attribute></attributes>"
    post "/source/home:adrian/_attribute", data
    assert_response :success
    get "/source/home:adrian/_attribute/TEST:Dummy"
    assert_response :success
    assert_no_xml_tag :parent => { :tag => 'attribute', :attributes => { :name => "Dummy", :namespace => "TEST" } },
                   :tag => 'issue', :attributes => { :name => "123", :tracker => "bnc" }
    assert_xml_tag :parent => { :tag => 'attribute', :attributes => { :name => "Dummy", :namespace => "TEST" } },
                   :tag => 'issue', :attributes => { :name => "456", :tracker => "bnc" }

    # cleanup
    delete "/attribute/TEST/Dummy/_meta"
    assert_response :success
    get "/attribute/TEST/Dummy/_meta"
    assert_response 404
  end

  def test_attrib_type_meta
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/attribute/OBS"
    assert_response :success
    count = 14
    assert_xml_tag :tag => 'directory', :attributes => { :count => count }
    assert_xml_tag :children => { :count => count }
    assert_xml_tag :child => { :tag => 'entry', :attributes => { :name => "Maintained" } }
  end

  def test_invalid_get
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/source/RemoteInstance:BaseDistro/pack1/_attribute"
    assert_response 404
  end

  def test_create_attributes_project
    prepare_request_with_user "tom", "thunder"

    data = "<attributes><attribute namespace='OBS' name='Playground'/></attributes>"
    post "/source/home:tom/_attribute", data
    assert_response 404
    assert_select "status[code] > summary", /unknown attribute type 'OBS:Playground'/ 

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute></attributes>"
    post "/source/home:tom/_attribute", data
    assert_response 403
    assert_select "status[code] > summary", /attribute 'OBS:Maintained' has 1 values, but only 0 are allowed/
  
    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post "/source/home:tom/_attribute", data
    assert_response :success
    post "/source/home:tom/_attribute/OBS:Maintained", data
    assert_response :success

    get "/source/home:tom/_attribute"
    assert_response :success
    get "/source/home:tom/_attribute/OBS:Maintained"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert_equal node.has_element?(:attribute), true
    assert_equal node.attribute.has_attribute?(:binary), false
    assert_equal node.attribute.namespace, "OBS"
    assert_equal node.attribute.name, "Maintained"

    get "/source/NOT_EXISTING/_attribute"
    assert_response 404
    get "/source/home:tom/_attribute/OBS:NotExisting"
    assert_response 404
    get "/source/home:tom/_attribute/NotExisting:NotExisting"
    assert_response 404

    # via remote link
    get "/source/RemoteInstance:home:tom/_attribute/OBS:Maintained"
    assert_response 400

    # via group
    prepare_request_with_user "adrian", "so_alone"
    data = "<attributes><attribute namespace='OBS' name='Maintained'></attribute></attributes>"
    post "/source/home:tom/_attribute", data
    assert_response :success

    # as admin
    prepare_request_with_user "king", "sunflower"
    post "/source/home:tom/_attribute", data
    assert_response :success

    # not allowed
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:tom/_attribute", data
    assert_response 403
    delete "/source/home:tom/_attribute/OBS:Maintained"
    assert_response 403
    get "/source/home:tom/_attribute/OBS:Maintained"
    assert_response :success

    # check history
    get "/source/home:tom/_project?meta=1"
    assert_response :success
    assert_xml_tag :tag => "entry", :attributes => { :name => "_attribute" }
    get "/source/home:tom/_project/_history?meta=1"
    assert_response :success
    assert_xml_tag( :tag => "revisionlist" )
    node = ActiveXML::Node.new(@response.body)
    revision = node.each_revision.last
    assert_equal revision.user.text, "tom"
    srcmd5 = revision.srcmd5.text

    # delete
    prepare_request_with_user "tom", "thunder"
    post "/source/home:tom/_attribute", data
    assert_response :success
    delete "/source/home:tom/_attribute/OBS:Maintained"
    assert_response :success
    delete "/source/home:tom/_attribute/OBS:Maintained"
    assert_response 404

    # get old revision
    # both ways need to work, first one for backward compatibility
    get "/source/home:tom/_attribute?rev=#{srcmd5}"
    assert_response :success
    assert_xml_tag( :tag => "attribute", :attributes => { :namespace => "OBS", :name => "Maintained" } )
    get "/source/home:tom/_project/_attribute?meta=1&rev=#{srcmd5}"
    assert_response :success
    assert_xml_tag( :tag => "attribute", :attributes => { :namespace => "OBS", :name => "Maintained" } )

    # get current
    get "/source/home:tom/_attribute/OBS:Maintained"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert_equal node.has_element?(:attribute), false
  end

  def test_create_attributes_package
    prepare_request_with_user "fred", "geröllheimer"

    data = "<attributes><attribute namespace='OBS' name='Playground'/></attributes>"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 404
    assert_select "status[code] > summary", /unknown attribute type 'OBS:Playground'/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <BROKENXML>
            </attribute></attributes>"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 400
    assert_select "status[code] > summary", /Invalid XML/

    data = "<attributes><attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute></attributes>"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 403
    assert_select "status[code] > summary", /attribute 'OBS:Maintained' has 1 values, but only 0 are allowed/

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
    node = ActiveXML::Node.new(@response.body)
    assert_equal node.has_element?(:attribute), true
    assert_equal node.attribute.has_attribute?(:binary), false
    assert_equal node.attribute.namespace, "OBS"
    assert_equal node.attribute.name, "Maintained"
    get "/source/kde4/kdelibs/kdelibs-devel/_attribute"
    assert_response :success
    get "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert_equal node.attribute.has_attribute?(:binary), true
    assert_equal node.attribute.binary, "kdelibs-devel"
    assert_equal node.attribute.namespace, "OBS"
    assert_equal node.attribute.name, "Maintained"

    get "/source/kde4/NOT_EXISTING/_attribute"
    assert_response 404

    # no permission check
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response 403
    post "/source/kde4/kdelibs/_attribute/OBS:Maintained", data
    assert_response 403
    post "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained", data
    assert_response 403
    delete "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained"
    assert_response 403
    get "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained"
    assert_response :success
    delete "/source/kde4/kdelibs/_attribute/OBS:Maintained"
    assert_response 403
    get "/source/kde4/kdelibs/_attribute/OBS:Maintained"
    assert_response :success

    # invalid operations
    delete "/source/kde4/kdelibs/kdelibs-devel/_attribute"
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "missing_attribute" }
    delete "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS_Maintained"
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "invalid_attribute" }

    # check history
    get "/source/kde4/kdelibs?meta=1"
    assert_response :success
    assert_xml_tag :tag => "entry", :attributes => { :name => "_attribute" }
    get "/source/kde4/kdelibs/_history?meta=1"
    assert_response :success
    assert_xml_tag( :tag => "revisionlist" )
    node = ActiveXML::Node.new(@response.body)
    revision = node.each_revision.last
    assert_equal revision.user.text, "fred"
    srcmd5 = revision.srcmd5.text

    # delete
    reset_auth
    prepare_request_with_user "fred", "geröllheimer"
    post "/source/kde4/kdelibs/_attribute", data
    assert_response :success
    post "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained", data
    assert_response :success
    delete "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained"
    assert_response :success
    get "/source/kde4/kdelibs/kdelibs-devel/_attribute/OBS:Maintained"
    assert_response :success
    delete "/source/kde4/kdelibs/_attribute/OBS:Maintained"
    assert_response :success
    get "/source/kde4/kdelibs/_attribute/OBS:Maintained"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert_equal node.has_element?(:attribute), false

    # get old revision
    get "/source/kde4/kdelibs/_attribute?meta=1&rev=#{srcmd5}"
    assert_response :success
    assert_xml_tag( :tag => "attribute", :attributes => { :namespace => "OBS", :name => "Maintained" } )
    assert_xml_tag( :tag => "attribute", :attributes => { :namespace => "OBS", :name => "Maintained", :binary => "kdelibs-devel" } )
  end

# FIXME:
# * value based test are missing

end

