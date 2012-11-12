require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class MonitorControllerTest < ActionDispatch::IntegrationTest

  def setup 
    login_tom
  end

  def test_monitor
    visit "/monitor"

    visit "/monitor/old"
  end
 
end
