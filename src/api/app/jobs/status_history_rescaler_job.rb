class StatusHistoryRescalerJob < ApplicationJob
  queue_as :quick

  # this is called from a delayed job triggered by clockwork
  def perform
    distinct_status_history_keys.each do |key|
      StatusHistory.transaction do
        # first rescale a month old
        cleanup(key, offset_from_now(12.hours.ago), 1.month.ago.to_i)
        # now a week old
        cleanup(key, offset_from_now(6.hours.ago), 7.days.ago.to_i)
        # now rescale yesterday
        cleanup(key, offset_from_now(1.hour.ago), 24.hours.ago.to_i)
        # 2h stuff
        cleanup(key, offset_from_now(4.minutes.ago), 2.hours.ago.to_i)
      end
    end
  end

  private

  def distinct_status_history_keys
    StatusHistory.distinct.pluck(:key)
  end

  def offset_from_now(date)
    (Time.now - date).to_i
  end

  def find_items(key, mintime, maxtime)
    StatusHistory.where('`key` = ? and `time` > ? and `time` < ?', key, mintime, maxtime).order(:time)
  end

  def cleanup(key, mintime, maxtime_offset)
    # we try to make sure all keys are in the same time slots,
    # so start with the overall time
    allitems = find_items(key, mintime, maxtime_offset)
    return if allitems.empty?

    time_average = allitems.average(:time)
    value_average = allitems.average(:value)
    StatusHistory.delete(allitems.map(&:id))
    StatusHistory.create(key: key, time: time_average, value: value_average)
  end
end
