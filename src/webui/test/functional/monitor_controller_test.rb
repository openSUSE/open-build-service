require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class MonitorControllerTest < ActionDispatch::IntegrationTest

  def test_monitor
    visit "/monitor"
    assert find(:id, "header-logo")

    visit "/monitor/old"
    assert find(:id, "header-logo")
  end
 
end
