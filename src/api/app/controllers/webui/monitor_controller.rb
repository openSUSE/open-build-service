class Webui::MonitorController < Webui::WebuiController
  before_action :require_settings, only: [:old, :index, :filtered_list, :update_building]
  before_action :fetch_workerstatus, only: [:old, :filtered_list, :update_building]

  class << self
    private_class_method
    def addarrays(arr1, arr2)
      # we assert that both have the same size
      ret = []
      if arr1
        arr1.length.times do |i|
          time1, value1 = arr1[i]
          time2, value2 = arr2[i]
          value2 ||= 0
          value1 ||= 0
          time1 ||= 0
          time2 ||= 0
          ret << [(time1 + time2) / 2, value1 + value2]
        end
      end
      ret << 0 if ret.length.zero?
      ret
    end
  end

  def old; end

  def index
    @default_architecture = 'x86_64'

    if request.post? && !params[:project].nil? && valid_project_name?(params[:project])
      redirect_to project: params[:project]
    else
      begin
        fetch_workerstatus
      rescue ActiveXML::Transport::NotFoundError
        @workerstatus = {}
      end

      workers = {}
      workers_list = []
      ['idle', 'building', 'away', 'down', 'dead'].each do |state|
        @workerstatus.elements(state) do |b|
          workers_list << [b['workerid'], b['hostarch']]
        end
      end
      workers_list.each do |bid, barch|
        hostname, subid = bid.gsub(%r{[:]}, '/').split('/')
        id = bid.gsub(%r{[:./]}, '_')
        workers[hostname] ||= {}
        workers[hostname]['_arch'] = barch
        workers[hostname][subid] = id
      end
      @workers_sorted = {}
      @workers_sorted = workers.sort_by { |a| a[0] } if workers
      @available_arch_list = Architecture.available.pluck(:name).sort
    end
  end

  def update_building
    check_ajax
    workers = {}
    max_time = 4 * 3600
    @workerstatus.elements('idle') do |b|
      id = b['workerid'].gsub(%r{[:./]}, '_')
      workers[id] = {}
    end

    @workerstatus.elements('building') do |b|
      id = b['workerid'].gsub(%r{[:./]}, '_')
      delta = (Time.now - Time.at(b['starttime'].to_i)).round
      delta = 5 if delta < 5
      delta = max_time if delta > max_time
      delta = (100 * Math.sin(Math.acos(1 - (Float(delta) / max_time)))).round
      delta = 100 if delta > 100
      workers[id] = { 'delta' => delta, 'project' => b['project'], 'repository' => b['repository'],
                      'package' => b['package'], 'arch' => b['arch'], 'starttime' => b['starttime'] }
    end
    # logger.debug workers.inspect
    render json: workers
  end

  def gethistory(key, range, cache = 1)
    cachekey = key + "-#{range}"
    Rails.cache.delete(cachekey, shared: true) unless cache
    Rails.cache.fetch(cachekey, expires_in: (range.to_i * 3600) / 150, shared: true) do
      hash = StatusHistory.history_by_key_and_hours(key, range)
      hash.sort_by { |a| a[0] }
    end
  end

  def events
    check_ajax
    data = {}
    required_parameters :arch, :range

    arch = params[:arch]
    range = params[:range]
    ['waiting', 'blocked', 'squeue_high', 'squeue_med'].each do |prefix|
      data[prefix] = gethistory(prefix + '_' + arch, range, !discard_cache?).map { |time, value| [time * 1000, value] }
    end
    ['idle', 'building', 'away', 'down', 'dead'].each do |prefix|
      data[prefix] = gethistory(prefix + '_' + map_to_workers(arch), range, !discard_cache?).map { |time, value| [time * 1000, value] }
    end
    low = {}
    gethistory("squeue_low_#{arch}", range).each do |time, value|
      low[time] = value
    end
    comb = []
    gethistory("squeue_next_#{arch}", range).each do |time, value|
      clow = low[time] || 0
      comb << [1000 * time, clow + value]
    end
    data['squeue_low'] = comb
    max = Webui::MonitorController.addarrays(data['squeue_high'], data['squeue_med']).map { |_, value| value }.max || 0
    data['events_max'] = max * 2
    data['jobs_max'] = maximumvalue(data['waiting']) * 2
    render json: data
  end

  private

  def fetch_workerstatus
    @workerstatus = WorkerStatus.hidden.to_hash
  end

  def maximumvalue(arr)
    arr.map { |_, value| value }.max || 0
  end

  def require_settings
    @project_filter = params[:project]

    # @interval_steps must be > 0:
    # @interval_steps * @max_color + @dead_line minutes
    @interval_steps = 1
    @max_color = 240
    @time_now = Time.now
    @dead_line = 1.hour.ago
  end
end
