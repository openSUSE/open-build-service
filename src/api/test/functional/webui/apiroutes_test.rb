require_relative '../../test_helper'

class Webui::MonitorControllerTest < Webui::IntegrationTest
  def test_API_routes_as_HTML # spec/routing/webui_matcher_spec.rb & spec/routing/api_matcher_spec.rb
    # this is only valid for XML queries
    visit '/distributions'
    page.status_code.must_equal 404

    visit '/request'
    page.status_code.must_equal 404
  end
end
