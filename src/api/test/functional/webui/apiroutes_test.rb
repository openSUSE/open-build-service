require_relative '../../test_helper'

class Webui::MonitorControllerTest < Webui::IntegrationTest

  test 'API routes as HTML' do
    # this is only valid for XML queries
    visit '/distributions'
    page.status_code.must_equal 404

    visit '/request'
    page.status_code.must_equal 404
  end
end
