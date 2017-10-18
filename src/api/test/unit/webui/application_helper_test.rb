require 'test_helper'

SimpleCov.command_name 'test:webui'

class ApplicationHelperTest < ActiveSupport::TestCase
  include Webui::WebuiHelper

  def test_repo_status_icon # spec/helpers/webui/webui_helper_spec.rb
    # Regular
    status = repo_status_icon('blocked')
    assert_match("icons-time", status)
    assert_match("No build possible atm", status)

    # Outdated
    status = repo_status_icon('outdated_scheduling')
    assert_match("icons-cog_error", status)
    assert_match("state is being calculated", status)
    assert_match("needs recalculations", status)

    # Fallback
    status = repo_status_icon('undefined')
    assert_match("icons-eye", status)
    assert_match("Unknown state", status)
  end
end
