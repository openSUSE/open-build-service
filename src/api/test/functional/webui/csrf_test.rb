require_relative '../../test_helper'

class Webui::CSRFTest < Webui::IntegrationTest
  def test_csfr_protection # src/api/spec/controllers/webui/project_controller_spec.rb
    login_tom
    page.driver.browser.process(:post, '/project/save_person/home%3Atom', { params: {
      userid:  "Admin",
      role:    "maintainer",
      project: "home%3Atom",
      commit:  "Add+user"
    }})
    assert page.status_code.eql? 950
  end
end
