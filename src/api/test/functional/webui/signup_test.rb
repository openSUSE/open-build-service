require 'test_helper'

class Webui::SignupTest < Webui::IntegrationTest

    def test_login
      login_user("tom", "thunderz", false)

      page.must_have_text("Please Log In")
      page.must_have_text("Authentication failed")
 
      login_user("tom", "thunder")
    end

end

