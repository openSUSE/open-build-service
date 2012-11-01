require File.join File.dirname(__FILE__), '..', 'test_helper'

include RequestHelper
include ActionView::Helpers::TagHelper

class RequestHelperTest < ActiveSupport::TestCase

  def test_request_state_icon
    request = RequestHelperTmp.new('new')
    assert_equal 'icons/flag_green.png', request_state_icon(request)

    request = RequestHelperTmp.new('unknown')
    assert_equal '', request_state_icon(request)
  end
end

class RequestHelperTmp
  @ret = nil
  def initialize(ret)
    @ret = ret
  end
  def state
    self
  end
  def value(key)
    @ret
  end
end
