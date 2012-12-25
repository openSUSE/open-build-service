require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

include RequestHelper
include ActionView::Helpers::TagHelper

require 'xmlhash'

class RequestHelperTest < ActiveSupport::TestCase

  def test_request_state_icon
    map_request_state_to_flag('new').must_equal 'flag_green'

    map_request_state_to_flag(nil).must_equal ''
  end
end

