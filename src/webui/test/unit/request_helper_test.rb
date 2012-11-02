require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

include RequestHelper
include ActionView::Helpers::TagHelper

require 'xmlhash'

class RequestHelperTest < ActiveSupport::TestCase

  def test_request_state_icon
    request = Xmlhash.parse("<request><state name='new'/></request>")
    assert_equal 'icons/flag_green.png', request_state_icon(request)

    request = Xmlhash.parse("<request/>")
    assert_equal '', request_state_icon(request)
  end
end

