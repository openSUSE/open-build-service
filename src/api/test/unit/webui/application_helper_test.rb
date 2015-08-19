require 'test_helper'

include Webui::WebuiHelper

module Webui
 module WebuiHelper
  def image_tag(filename, opts = {})
    "<img class='#{opts.inspect}'/>"
  end
 end
end
class ApplicationHelperTest < ActiveSupport::TestCase
  def test_repo_status_icon
    # Regular
    status = Webui::WebuiHelper::repo_status_icon("blocked")
    status.must_match(/icons-time/)
    status.must_match(/No build possible atm/)

    # Outdated
    status = Webui::WebuiHelper::repo_status_icon("outdated_scheduling")
    status.must_match(/icons-cog_error/)
    status.must_match(/state is being calculated/)
    status.must_match(/needs recalculations/)

    # Fallback
    status = Webui::WebuiHelper::repo_status_icon("undefined")
    status.must_match(/icons-eye/)
    status.must_match(/Unknown state/)
  end
end
