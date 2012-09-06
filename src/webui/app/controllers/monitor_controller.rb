class MonitorController < ApplicationController

  before_filter :require_settings, :only => [:old, :index, :filtered_list, :update_building]
  before_filter :require_available_architectures, :only => [:index]
  before_filter :fetch_workerstatus, :only => [:old, :filtered_list, :update_building]

  def fetch_workerstatus
     @workerstatus = Workerstatus.find(:all).to_hash
     Rails.cache.write('frontpage_workerstatus', @workerstatus, :expires_in => 15.minutes)
  end
  private :fetch_workerstatus

  def old
  end

  def index
    if request.post? && ! params[:project].nil? && valid_project_name?( params[:project] )
      redirect_to :project => params[:project]
    else
      begin
         fetch_workerstatus
      rescue ActiveXML::Transport::NotFoundError
         @workerstatus = {}
      end

      workers = Hash.new
      workers_list = Array.new
      @workerstatus.elements("building") do |b|
        workers_list << [b["workerid"], b["hostarch"]]
      end
      @workerstatus.elements("idle") do |b|
        workers_list << [b["workerid"], b["hostarch"]]
      end
      workers_list.each do |bid, barch|
        hostname, subid = bid.gsub(%r{[-:]}, '/').split('/')
        id=bid.gsub(%r{[:./]}, '_')
        workers[hostname] ||= Hash.new
        workers[hostname]['_arch'] = barch
        workers[hostname][subid] = id
      end
      @workers_sorted = {}
      @workers_sorted = workers.sort {|a,b| a[0] <=> b[0] } if workers
      @available_arch_list = @available_architectures.each.map{|arch| arch.name}
    end
  end

  def filtered_list
    render :partial => 'building_table'
  end

  def update_building
    workers = Hash.new
    max_time = 4 * 3600
    @workerstatus.elements("idle") do |b|
      id=b["workerid"].gsub(%r{[-:./]}, '_')
      workers[id] = Hash.new
    end

    @workerstatus.elements("building") do |b|
      id=b["workerid"].gsub(%r{[-:./]}, '_')
      delta = (Time.now - Time.at(b["starttime"].to_i)).round
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
      workers[id] = { "delta" => delta, "project" => b["project"], "repository" => b["repository"], 
	"package" => b["package"], "arch" => b["arch"], "starttime" => b["starttime"]}
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
    max = MonitorController.addarrays(data["squeue_high"], data["squeue_med"]).map{|time,value| value}.max || 0
    data["events_max"] = max * 2
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

  def require_settings
    @project_filter = params[:project]

    # @interval_steps must be > 0:
    # @interval_steps * @max_color + @dead_line minutes
    @interval_steps = 1
    @max_color = 240
    @time_now = Time.now
    @dead_line = 1.hours.ago
  end

end
