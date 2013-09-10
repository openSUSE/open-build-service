require 'test_helper'

class BackendInfoTest < ActiveSupport::TestCase
  test "basics" do
     assert_equal BackendInfo.lastnotification_nr, 0
     BackendInfo.lastnotification_nr = 42
     assert_equal BackendInfo.lastnotification_nr, 42
  end

end
