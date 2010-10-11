require 'gruff'

class MonitorController < ApplicationController

  skip_before_filter :check_user, :only => [ :plothistory ]

  def old
    get_settings
    check_user
    @workerstatus = Workerstatus.find :all
    Rails.cache.write('frontpage_workerstatus', @workerstatus, :expires_in => 15.minutes)
    @status_messages = get_status_messages
  end

  def index
    get_settings
    check_user
    if request.post? && ! params[:project].nil? && valid_project_name?( params[:project] )
      redirect_to :project => params[:project]
    else
      begin
         @workerstatus = Workerstatus.find :all
         Rails.cache.write('frontpage_workerstatus', @workerstatus, :expires_in => 15.minutes)
      rescue ActiveXML::Transport::NotFoundError
         @workerstatus = nil
      end
      @status_messages = get_status_messages

      workers = Hash.new
      workers_list = Array.new
      if @workerstatus
        @workerstatus.each_building.each do |b|
          workers_list << [b.workerid, b.hostarch]
        end
        @workerstatus.each_idle.each do |b|
          workers_list << [b.workerid, b.hostarch]
        end
      end
      workers_list.each do |bid, barch|
	hostname, subid = bid.gsub(%r{[:]}, '/').split('/')
        id=bid.gsub(%r{[:./]}, '_')
	workers[hostname] ||= Hash.new
	workers[hostname]['_arch'] = barch
	workers[hostname][subid] = id
      end
      @workers_sorted = workers.sort {|a,b| a[0] <=> b[0] }
    end
  end


  def add_message_form
    render :partial => 'add_message_form'
  end


  def save_message
    message = Statusmessage.new(
      :message => params[:message],
      :severity => params[:severity].to_i
    )
    begin
      message.save
    rescue ActiveXML::Transport::ForbiddenError
      @denied = true
    end
    @status_messages = get_status_messages
  end


  def delete_message
    message = Statusmessage.find( :id => params[:id] )
    begin
      message.delete
    rescue ActiveXML::Transport::ForbiddenError
      @denied = true
    end
    @status_messages = get_status_messages
  end


  def show_more_messages
    @status_messages = get_status_messages 100
  end


  def get_status_messages( limit=nil )
    @max_messages = 4
    limit ||= params[:message_limit]
    limit = @max_messages if limit.nil?
    return Statusmessage.find( :limit => limit )
  end


  def filtered_list
    get_settings
    @workerstatus = Workerstatus.find :all
    Rails.cache.write('frontpage_workerstatus', @workerstatus, :expires_in => 15.minutes)
    render :partial => 'building_table'
  end


  def get_settings
    @project_filter = params[:project]

    # @interval_steps must be > 0:
    # @interval_steps * @max_color + @dead_line minutes
    @interval_steps = 1
    @max_color = 240
    @time_now = Time.now
    @dead_line = 1.hours.ago
  end


  def update_building
    get_settings
    begin
       workerstatus = Workerstatus.find :all
    rescue Timeout::Error
       render :json => []
       return
    end
    workers = Hash.new
    max_time = 4 * 3600
    workerstatus.each_idle do |b|
      id=b.workerid.gsub(%r{[:./]}, '_')
      workers[id] = Hash.new
    end

    workerstatus.each_building do |b|
      id=b.workerid.gsub(%r{[:./]}, '_')
      delta = (Time.now - Time.at(b.starttime.to_i)).round
      if delta < 5
	delta = 5
      end
      if delta > max_time
        delta = max_time
      end
      delta = (100*Math.sin(Math.acos(1-(Float(delta)/max_time)))).round
      if (delta > 100)
	delta = 100
      end
      workers[id] = { "delta" => delta, "project" => b.project, "repository" => b.repository, 
	"package" => b.package, "arch" => b.arch, "starttime" => b.starttime}
    end
    # logger.debug workers.inspect
    render :json => workers
  end

  def events
    data = Hash.new
    required_parameters :arch, :range

    arch = params[:arch]
    range = params[:range]
    %w{waiting blocked squeue_high squeue_med}.each do |prefix|
      data[prefix] = frontend.gethistory(prefix + "_" + arch, range, !discard_cache?).map {|time,value| [time*1000,value]}
    end
    %w{idle building}.each do |prefix|
      data[prefix] = frontend.gethistory(prefix + "_" + map_to_workers(arch), range, !discard_cache?).map {|time,value| [time*1000,value]}
    end
    low = Hash.new
    frontend.gethistory("squeue_low_#{arch}", range).each do |time,value|
      low[time] = value
    end
    comb = Array.new
    frontend.gethistory("squeue_next_#{arch}", range).each do |time,value|
      clow = low[time] || 0
      comb << [1000*time, clow + value]
    end
    data["squeue_low"] = comb
    data["events_max"] = MonitorController.addarrays(data["squeue_high"], data["squeue_med"]).map{|time,value| value}.max * 2
    data["jobs_max"] =  maximumvalue(data["waiting"]) * 2
    render :json => data
  end

private
  
  def maximumvalue(arr)
    arr.map { |time,value| value }.max || 0
  end

  def self.addarrays(arr1, arr2)
    logger.debug "1: #{arr1.length} 2: #{arr2.length}"
    # we assert that both have the same size
    ret = Array.new
    arr1.length.times do |i|
      time1, value1 = arr1[i]
      time2, value2 = arr2[i]
      ret << [(time1+time2)/2, value1 + value2]
    end if arr1
    ret << 0 if ret.length == 0
    return ret
  end

end
