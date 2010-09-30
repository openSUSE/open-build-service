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
      @workers_sorted = workers.sort {|a,b| a[1].size == b[1].size ? a[0] <=> b[0] : b[1].size <=> a[1].size }
      logger.debug @workers_sorted.inspect
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


  # :range = range in hours
  def plothistory
    set = params[:set]
    range = params[:range]
    cache_key = "monitor_plot_#{set}_#{range}"
    data = Rails.cache.fetch(cache_key, :expires_in => (range.to_i * 3600) / 150, :raw => true) do
      plothistory_data(set, range.to_i)
    end
    if data && data.respond_to?( 'bytesize' )
      headers['Content-Type'] = 'image/png'
      send_data(data, :type => 'image/png', :disposition => 'inline')
    else
      render_error :code => 404, :message => "No plot data found for range=#{range} and set=#{set}", :status => 404
    end
  end


private

  def plothistory_data(set, range)
    return unless [1, 24, 72, 168].include? range

    g = Gruff::StackedArea.new(400)
    g.title = nil
    g.theme = {
      :colors => [
        '#a9a9da', # blue
        '#aedaa9', # green
        '#daaea9', # peach
        '#dadaa9', # yellow
        '#a9a9da', # dk purple
        '#daaeda', # purple
        '#dadada' # grey
      ], 
      :marker_color => '#aea9a9', # Grey
      :font_color => 'black',
      :background_colors => ['#d1edf5', 'white']
    }

    if MONITOR_IMAGEMAP.has_key?(set)
      array = Array.new
      MONITOR_IMAGEMAP[set].each do |f|
        array << gethistory(f[1], range)
      end
      array = resample(array)
      g.labels = array[0]
      g.bottom_margin = 0
      g.center_labels_over_point = true
      g.last_series_goes_on_bottom = true

      index = 1
      MONITOR_IMAGEMAP[set].each do |f|
        g.data(f[0], array[index])
        index += 1
      end
      g.minimum_value = 0
    else
      g.data('no data', [])
    end
    return g.to_blob()
  end

  def gethistory(key, range)
    hash = Hash.new
    data = frontend.transport.direct_http(URI('/public/status/history?key=%s&hours=%d&samples=1000' % [key, range]))
    d = XML::Parser.string(data).parse
    d.root.each_element do |v|
      hash[Integer(v.attributes['time'])] = v.attributes['value'].to_f
    end
    hash.sort {|a,b| a[0] <=> b[0]}
  end

  def resample(values)
    min_x = Time.now.to_i + 80000 # really really huge
    max_x = 0
    result = Array.new
    
    # assume arrays are sorted
    values.each do |a|
      next if a.length == 0
      min_x = [min_x, a[0][0]].min
      max_x = [max_x, a[-1][0]].max
    end

    samples = 200
    samplerate = (max_x - min_x) / samples

    labels = Hash.new
    0.upto(6) do |i|
       index = Integer(samples * i / 6) - 1
       labels[index] = Time.at(min_x + index * samplerate).strftime("%H:%M")
    end

    result << labels
    values.each do |a|
      now = min_x
      till = min_x + samplerate
      index = 0
      array = []

      1.upto(samples) do |i|
	value = 0
	count = 0
	while index < a.length && a[index][0] < till
	  value += a[index][1]
	  index += 1
	  count += 1
	end
	till += samplerate
	if count > 0
	  array << Float(value) / count
	else
	  array << Float(0)
	end
      end

      result << array
    end
    return result
  end
end
