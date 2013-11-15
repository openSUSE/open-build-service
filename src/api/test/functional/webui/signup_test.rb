require_relative '../../test_helper'

class Webui::SignupTest < Webui::IntegrationTest

    def test_login
      login_user('tom', 'thunderz', do_assert: false)

      page.must_have_text('Please Log In')
      page.must_have_text('Authentication failed')
 
      login_user('tom', 'thunder')
    end

end

