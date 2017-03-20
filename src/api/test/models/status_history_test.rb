require 'test_helper'

class StatusHistoryTest < ActiveSupport::TestCase
  def setup
    StatusHistory.delete_all
  end

  def teardown
    Timecop.return
  end

  test "rescale" do
    Timecop.freeze(2010, 7, 12) do
      now = Time.now.to_i - 2.days
      StatusHistory.transaction do
        1000.times do |i|
          StatusHistory.create time: now + i, key: 'idle_x86_64', value: i
        end
      end

      StatusHistory.create! time: Time.now.to_i, key: 'busy_x86_64', value: 100

      assert_equal 1001, StatusHistory.count
      StatusHistoryRescaler.new.rescale
      assert_equal 2, StatusHistory.count

      rel = StatusHistory.where(key: 'idle_x86_64')
      assert_equal 1, rel.count
      assert_equal 499.5, rel.first.value
    end
  end

  test "history_by_key_and_hours" do
    Timecop.freeze(2010, 7, 12) do
      day_before_yesterday = Time.now.to_i - 2.days
      yesterday = Time.now.to_i - 1.day
      StatusHistory.transaction do
        10.times do |i|
          StatusHistory.create time: day_before_yesterday + i, key: 'squeue_low_aarch64', value: i
        end
        5.times do |i|
          StatusHistory.create time: yesterday + i, key: 'squeue_low_aarch64', value: i
        end
      end
      assert_equal 5, StatusHistory.history_by_key_and_hours('squeue_low_aarch64', 25).count
      assert_equal 15, StatusHistory.history_by_key_and_hours('squeue_low_aarch64', 49).count
    end
  end
end
