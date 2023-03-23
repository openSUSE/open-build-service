require_relative '../test_helper'

class StatusHistoryTest < ActiveSupport::TestCase
  def setup
    StatusHistory.delete_all
  end

  test 'history_by_key_and_hours' do
    day_before_yesterday = Time.now.to_i - 2.days
    yesterday = Time.now.to_i - 1.day
    StatusHistory.transaction do
      10.times do |i|
        StatusHistory.create(time: day_before_yesterday + i, key: 'squeue_low_aarch64', value: i)
      end
      5.times do |i|
        StatusHistory.create(time: yesterday + i, key: 'squeue_low_aarch64', value: i)
      end
    end
    assert_equal 5, StatusHistory.history_by_key_and_hours('squeue_low_aarch64', 25).count
    assert_equal 15, StatusHistory.history_by_key_and_hours('squeue_low_aarch64', 49).count
  end
end
