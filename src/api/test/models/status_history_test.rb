require 'test_helper'

class StatusHistoryTest < ActiveSupport::TestCase

  def teardown
    Timecop.return
  end

  test "rescale" do
    Timecop.freeze(2010, 7, 12)
    now = Time.now.to_i - 2.days
    StatusHistory.transaction do
      1000.times do |i|
        StatusHistory.create time: now + i, key: 'idle_x86_64', value: i
      end
    end

    StatusHistory.create time: Time.now.to_i, key: 'busy_x86_64', value: 100

    assert_equal 1001, StatusHistory.count
    StatusHistoryRescaler.new.rescale
    assert_equal 2, StatusHistory.count

    rel = StatusHistory.where(key: 'idle_x86_64')
    assert_equal 1, rel.count
    assert_equal 499.5, rel.first.value
  end
end
