require File.join File.dirname(__FILE__), '..', 'test_helper'

include ApplicationHelper
include ActionView::Helpers::TagHelper

class ApplicationHelperTest < ActiveSupport::TestCase
  def test_repo_status_icon
    # Regular
    status = ApplicationHelper::repo_status_icon("blocked")
    assert status.match /icons-time/
    assert status.match /No build possible atm/

    # Outdated
    status = ApplicationHelper::repo_status_icon("outdated_scheduling")
    assert status.match /icons-cog_error/
    assert status.match /state is being calculated/
    assert status.match /needs recalculations/

    # Fallback
    status = ApplicationHelper::repo_status_icon("undefined")
    assert status.match /icons-eye/
    assert status.match /Unknown state/
  end

  def test_sponsors
    assert_not_nil get_random_sponsor_image
  end
end
