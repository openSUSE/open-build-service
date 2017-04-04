require 'test_helper'

class WorkerStatusTest < ActiveSupport::TestCase
  test "update cache" do
    Backend::Connection.wait_for_scheduler_start
    WorkerStatus.new.update_workerstatus_cache
  end
end
