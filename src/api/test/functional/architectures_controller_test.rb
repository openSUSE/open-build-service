require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ArchitecturesControllerTest < ActionController::IntegrationTest
  def test_index
    reset_auth
    # Get all issue trackers
    get '/architectures'
    assert_response 401
    
    prepare_request_valid_user
    get '/architectures'
    assert_response :success
   
    assert_xml_tag tag: "entry", attributes: { recommended: "true", available: "false", name: "x86_64" }
    assert_xml_tag tag: "entry", attributes: { recommended: "false", available: "false", name: "ppc" }
 
  end

  def test_show
    prepare_request_valid_user
    get "/architectures/i586"
    assert_response :success
    
    assert_xml_tag tag: "architecture", attributes: { name: "i586" }, child: { tag: "available", content: "false" }

    get "/architectures/futurearch"
    assert_response 400
    assert_xml_tag tag: "status", attributes: { code: "unknown_architecture" }

  end

  def test_create
    prepare_request_valid_user
    put "/architectures/futurearch", "<architecture><available>true</available></architecture>"
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/architectures/futurearch", "<architecture><available>true</available></architecture>"
    assert_response 400
    assert_xml_tag tag: "status", attributes: { code: "unknown_architecture" }

    # temporary disabled to create
    post "/architectures/futurearch", "<architecture><available>true</available></architecture>"
    assert_response 404 
    assert_xml_tag tag: "status", attributes: { code: "not_found" }

  end

  def test_update
    prepare_request_with_user "king", "sunflower"
    get "/architectures/i586"
    assert_response :success

    xml = ActiveXML::Base.new @response.body
    xml.available.text = "true"
    put "/architectures/i586", xml.dump_xml
    assert_response :success
  end

end
