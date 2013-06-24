require File.join File.dirname(__FILE__), '..', 'test_helper'

include ApplicationHelper

module ApplicationHelper
  def image_tag(filename, opts = {})
    "<img class='#{opts.inspect}'/>"
  end
end
class ApplicationHelperTest < ActiveSupport::TestCase
  def test_repo_status_icon
    # Regular
    status = ApplicationHelper::repo_status_icon("blocked")
    status.must_match(/icons-time/)
    status.must_match(/No build possible atm/)

    # Outdated
    status = ApplicationHelper::repo_status_icon("outdated_scheduling")
    status.must_match(/icons-cog_error/)
    status.must_match(/state is being calculated/)
    status.must_match(/needs recalculations/)

    # Fallback
    status = ApplicationHelper::repo_status_icon("undefined")
    status.must_match(/icons-eye/)
    status.must_match(/Unknown state/)
  end
end
