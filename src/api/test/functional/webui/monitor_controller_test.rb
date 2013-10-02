require 'test_helper'

class Webui::MonitorControllerTest < Webui::IntegrationTest

  def test_monitor
    visit webui_engine.monitor_path
    assert find(:id, "header-logo")

    visit webui_engine.monitor_old_path
    assert find(:id, "header-logo")
  end
 
end
