class AddMissingIdles < ActiveRecord::Migration
  def self.up
    sql = ActiveRecord::Base.connection();
    archs = StatusHistory.find( :all, :select => 'DISTINCT `key`', :conditions => '`key` like "building_%"' ).collect {|item| item.key.gsub(%r{building_},'') }
    archs.each do |arch|
      idle_times = Hash.new
      StatusHistory.find(:all, :select => 'time', :conditions => "`key` = 'idle_#{arch}'").each { |item| idle_times[item.time] = 1 }
      building_times = Hash.new
      StatusHistory.find(:all, :select => 'time', :conditions => "`key` = 'building_#{arch}'").each { |item| building_times[item.time] = 1 }
      sql.execute("begin")
      lcount = 0
      idle_times.keys.each do |time|
	unless building_times.has_key? time
	  sql.execute("insert into `status_histories` (`time`, `value`, `key`) VALUES(#{time}, 0, 'building_#{arch}')")
	  lcount = lcount + 1
	  if lcount > 2000
	    sql.execute("commit")
	    sql.execute("begin")
	    lcount = 0
	  end
	end
      end
      building_times.keys.each do |time|
	unless idle_times.has_key? time
	  sql.execute("insert into `status_histories` (`time`, `value`, `key`) VALUES(#{time}, 0, 'idle_#{arch}')")
	  lcount = lcount + 1
	  if lcount > 2000
	    sql.execute("commit")
	    sql.execute("begin")
	    lcount = 0
	  end
	end
      end
      sql.execute("commit")
    end
  end

  def self.down
    # no harm done in not reverting
  end
end
