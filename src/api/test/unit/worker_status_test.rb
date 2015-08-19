require 'test_helper'

class WorkerStatusTest < ActiveSupport::TestCase

  test "update cache" do
    WorkerStatus.new.update_workerstatus_cache
  end

end
