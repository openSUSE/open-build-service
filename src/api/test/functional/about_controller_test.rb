require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class AboutControllerTest < ActionController::IntegrationTest 

  def setup
    prepare_request_valid_user
  end
 
  def test_about
    get "/about"
    assert_response :success
    assert_tag( :tag => "about", :descendant => { :tag => "revision" } )
  end

  def test_application_controller
    get "/about?user[asd]=yxc"
    assert_response 400
    assert_tag( :tag => "status", :attributes => { :code => "invalid_parameter" } )
  end

end
