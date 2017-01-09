require_relative '../test_helper'

class BackendInfoTest < ActiveSupport::TestCase
  test "basics" do
    old = BackendInfo.lastnotification_nr
    BackendInfo.lastnotification_nr = 42
    assert_equal BackendInfo.lastnotification_nr, 42
    BackendInfo.lastnotification_nr = old
    assert_equal BackendInfo.lastnotification_nr, old
  end
end
