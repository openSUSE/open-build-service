require 'test_helper'

class WorkerStatusTest < ActiveSupport::TestCase
  test 'update cache' do
    Backend::Test.start(wait_for_scheduler: true)
    WorkerStatus.new.update_workerstatus_cache
  end
end
