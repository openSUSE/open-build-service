require 'test_helper'

class BackendInfoTest < ActiveSupport::TestCase
  test "basics" do
     assert_equal BackendInfo.lastevents_nr, 0
     BackendInfo.lastevents_nr = 42
     assert_equal BackendInfo.lastevents_nr, 42
  end

end
