require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class MonitorControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_monitor
    get "/monitor"
    assert_response :success

    get "/monitor/old"
    assert_response :success
  end
 
end
