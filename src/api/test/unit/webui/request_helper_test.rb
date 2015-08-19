require 'test_helper'

include Webui::RequestHelper

class Webui::RequestHelperTest < ActiveSupport::TestCase

  def test_request_state_icon
    map_request_state_to_flag('new').must_equal 'flag_green'

    map_request_state_to_flag(nil).must_equal ''
  end
end

