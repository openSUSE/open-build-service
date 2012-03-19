require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ApidocsControllerTest < ActionController::IntegrationTest 

  def setup
    prepare_request_valid_user
  end

  def test_index
    # rails 3 will always go to #index
    get "/apidocs"
    assert_response :success
    
    get "/apidocs/" 
    assert_response :success
    # no interest in comparing with index.html
  end

  def test_subpage
    get "/apidocs/whatisthis"
    assert_response 404
    assert_xml_tag :attributes => { :code => "unknown_file_type" }

    get "/apidocs/whatisthis.xml"
    assert_response 404
    assert_xml_tag :attributes => { :code => "file_not_found" }
    
    get "/apidocs/project.xml" 
    assert_response :success
  end

end
