require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ApidocsControllerTest < ActionController::IntegrationTest 

  def setup
    prepare_request_valid_user
  end

  def test_index
    get "/apidocs"
    assert_response 302
    
    get "/apidocs/" 
    assert_response :success
    # no interest in comparing with index.html
  end

  def test_subpage
    get "/apidocs/whatisthis"
    assert_response 404
    assert_match(/code="unknown_file_type"/, @response.body)

    get "/apidocs/whatisthis.xml"
    assert_response 404
    assert_match(/code="file_not_found"/, @response.body)
    
    get "/apidocs/project.xml" 
    assert_response :success
  end

end
