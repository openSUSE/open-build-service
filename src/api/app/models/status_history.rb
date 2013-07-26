class StatusHistory < ActiveRecord::Base

  # this is called from a delayed job triggered by clockwork
  def rescale
    maxtime = StatusHistory.maximum(:time)
    if maxtime
      StatusHistory.where("time < ?", maxtime-365*24*3600).delete_all
    end

    def cleanup(key, offset, maxtimeoffset)

      # we try to make sure all keys are in the same time slots, so start with the overall time
      maxtime = StatusHistory.maximum(:time)
      maxtime -= maxtimeoffset
      maxtime = (maxtime / offset) * offset

      mintime = StatusHistory.minimum(:time)
      mintime = (mintime / offset) * offset

      allitems = StatusHistory.where('`key` = ? and `time` < ?', key, maxtime).order(:time).to_a
      return unless allitems.length > 0
      curmintime = mintime
      while allitems.length > 0
        items = []

        while allitems.length > 0 && allitems[0].time < curmintime + offset do
          items << allitems.shift
        end

        if items.length > 1
          timeavg = curmintime + offset / 2
          valuavg = (items.inject(0) { |sum, item| sum+item.value }).to_f / items.length
          Rails.logger.debug "scaling #{key} #{curmintime} #{items.length} #{Time.at(timeavg)} #{valuavg}"
          StatusHistory.delete(items.map { |i| i.id })
          StatusHistory.create :key => key, :time => timeavg, :value => valuavg
        end
        curmintime += offset
      end
    end

    keys = StatusHistory.pluck('DISTINCT `key`')
    keys.each do |key|
      StatusHistory.transaction do

        # first rescale a month old
        cleanup(key, 3600 * 12, 24 * 3600 * 30)
        # now a week old
        cleanup(key, 3600 * 6, 24 * 3600 * 7)
        # now rescale yesterday
        cleanup(key, 3600, 24 * 3600)
        # 2h stuff
        cleanup(key, 1200, 3600 * 2)
      end
    end
  end
end

