namespace :db do
  namespace :history do


    desc "Rescale old status histories"
    task :rescale => :environment do
      logger = RAILS_DEFAULT_LOGGER
      # we try to make sure all keys are in the same time slots, so start with the overall time
      mintime = StatusHistory.find( :first, :select => 'min(`time`) as time' ).time
      offset = 3600 * 6
      mintime = (mintime / offset) * offset
      maxtime = maxtime = StatusHistory.find( :first, :select => 'max(`time`) as time' ).time
      maxtime -= 24 * 3600 * 21
      maxtime = (maxtime / offset) * offset

      keys = StatusHistory.find( :all, :select => 'DISTINCT `key`' ).collect {|item| item.key}
      keys.each do |key|
        allitems = StatusHistory.find( :all, :conditions => [ '`key` = ? and `time` < ?',
                                       key, maxtime ], :order => :time )
	next unless allitems.length > 0
        curmintime = mintime
        while allitems.length > 0
          items = []
          
	  while allitems.length > 0 && allitems[0].time < curmintime + offset do
	    items << allitems.shift
	  end

          if items.length > 1
	    timeavg = curmintime + offset / 2
	    valuavg = (items.inject(0) { |sum,item| sum+item.value}).to_f / items.length
	    puts "scaling #{key} #{curmintime} #{items.length} #{Time.at(timeavg)} #{valuavg}"
            StatusHistory.transaction do 
  	      StatusHistory.delete(items.map {|i| i.id})
              StatusHistory.create :key => key, :time => timeavg, :value => valuavg
            end
          end
          curmintime += offset
        end
      end
      #sql = ActiveRecord::Base.connection();
      #sql.execute "optimize table status_histories;"
    end


  end
end
