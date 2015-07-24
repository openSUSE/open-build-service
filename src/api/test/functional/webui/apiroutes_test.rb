require_relative '../../test_helper'

class Webui::MonitorControllerTest < Webui::IntegrationTest

  def test_API_routes_as_HTML
    # this is only valid for XML queries
    visit '/distributions'
    page.status_code.must_equal 404

    visit '/request'
    page.status_code.must_equal 404
  end
end
