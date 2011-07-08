require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class RequestControllerTest < ActionController::IntegrationTest

  def setup
    login_tom
  end

  def test_request
    get "/requests"
    assert_response 404
  end

  def teardown
    logout
  end
 
end
