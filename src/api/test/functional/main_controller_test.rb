require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class MainTests < ActionController::IntegrationTest 
  
  def test_index
    reset_auth
    get "/"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/"
    assert_redirected_to "/about"
    follow_redirect!
    
    assert_xml_tag parent: { tag: "about" }, tag: "title"
  end

end
