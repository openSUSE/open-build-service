class StatusHistoryRescalerJob < ApplicationJob
  queue_as :quick

  # this is called from a delayed job triggered by clockwork
  def perform
    maxtime = StatusHistory.maximum(:time)
    StatusHistory.where(time: ...maxtime - (365 * 24 * 3600)).delete_all if maxtime

    keys = StatusHistory.distinct.pluck(:key)
    keys.each do |key|
      StatusHistory.transaction do
        # first rescale a month old
        cleanup(key, 3600 * 12, 24 * 3600 * 30)
        # now a week old
        cleanup(key, 3600 * 6, 24 * 3600 * 7)
        # now rescale yesterday
        cleanup(key, 3600, 24 * 3600)
        # 2h stuff
        cleanup(key, 200, 3600 * 2)
      end
    end
  end

  private

  def find_items_for_maxtime(key, maxtimeoffset)
    maxtime = StatusHistory.maximum(:time) - maxtimeoffset

    StatusHistory.where('`key` = ? and `time` < ?', key, maxtime).order(:time).to_a
  end

  def find_start_items(allitems, max)
    items = []

    items << allitems.shift while allitems.present? && allitems[0].time < max
    items
  end

  def cleanup(key, offset, maxtimeoffset)
    # we try to make sure all keys are in the same time slots, so start with the overall time
    allitems = find_items_for_maxtime(key, maxtimeoffset)
    return if allitems.empty?

    curmintime = StatusHistory.minimum(:time)

    until allitems.empty?
      items = find_start_items(allitems, curmintime + offset)

      if items.length > 1
        timeavg = curmintime + (offset / 2)
        valuavg = (items.inject(0) { |sum, item| sum + item.value }).to_f / items.length
        Rails.logger.debug { "scaling #{key} #{curmintime} #{items.length} #{Time.at(timeavg)} #{valuavg}" }
        StatusHistory.delete(items.map(&:id))
        StatusHistory.create(key: key, time: timeavg, value: valuavg)
      end
      curmintime += offset
    end
  end
end
