namespace :db do
  namespace :history do


    desc "Rescale old status histories"
    task :rescale => :environment do
     logger = Rails.logger

     maxtime = StatusHistory.find( :first, :select => 'max(`time`) as time' ).time
     sql = ActiveRecord::Base.connection()
     sql.execute "delete from status_histories where time < #{maxtime-365*24*3600}"

     def cleanup(key, offset, maxtimeoffset)

      # we try to make sure all keys are in the same time slots, so start with the overall time
      maxtime = StatusHistory.find( :first, :select => 'max(`time`) as time' ).time
      maxtime -= maxtimeoffset
      maxtime = (maxtime / offset) * offset

      mintime = StatusHistory.find( :first, :select => 'min(`time`) as time' ).time
      mintime = (mintime / offset) * offset
      
      allitems = StatusHistory.find( :all, :conditions => [ '`key` = ? and `time` < ?',
                                     key, maxtime ], :order => :time )
	return unless allitems.length > 0
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
  	    StatusHistory.delete(items.map {|i| i.id})
            StatusHistory.create :key => key, :time => timeavg, :value => valuavg
           end
           curmintime += offset
          end
     end
     
     keys = StatusHistory.find( :all, :select => 'DISTINCT `key`' ).collect {|item| item.key}
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
     sql.execute "optimize table status_histories;"
    end

  end
end
