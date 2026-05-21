class Webui::MonitorController < Webui::WebuiController
  before_action :set_default_architecture
  before_action :require_settings, only: %i[old index update_building]
  before_action :fetch_workerstatus, only: [:old]
  before_action :check_ajax, only: %i[update_building events]

  DEFAULT_SEARCH_RANGE = 24

  HOURS_IN_ONE_YEAR = 8760

  def index
    if request.post? && !params[:project].nil? && Project.valid_name?(params[:project])
      redirect_to project: params[:project]
    else
      begin
        fetch_workerstatus
      rescue Backend::NotFoundError
        @workerstatus = {}
      end

      workers = {}
      workers_list = []
      %w[idle building away down dead].each do |state|
        @workerstatus.elements(state) do |b|
          workers_list << [b['workerid'], b['hostarch']]
        end
      end
      workers_list.each do |bid, barch|
        hostname, subid = bid.tr(':', '/').split('/')
        id = bid.gsub(%r{[:./]}, '_')
        workers[hostname] ||= {}
        workers[hostname]['_arch'] = barch
        workers[hostname][subid] = id
      end
      @workers_sorted = {}
      @workers_sorted = workers.sort_by { |a| a[0] } if workers
      @available_arch_list = Architecture.available.order(:name).pluck(:name)
    end
  end

  def update_building
    building_info_updater = MonitorControllerService::BuildingInformationUpdater.new.call
    render json: building_info_updater.workers
  end

  def events
    data = {}

    arch = Architecture.find_by(name: params.fetch(:arch, @default_architecture).to_s)
    return render json: {} unless arch

    range = params.fetch(:range, DEFAULT_SEARCH_RANGE)

    %w[waiting blocked squeue_high squeue_med].each do |prefix|
      data[prefix] = status_history("#{prefix}_#{arch.name}", range).map { |time, value| [time * 1000, value] }
    end

    %w[idle building away down dead].each do |prefix|
      data[prefix] = status_history("#{prefix}_#{arch.worker}", range).map { |time, value| [time * 1000, value] }
    end

    low = status_history("squeue_low_#{arch}", range).to_h

    comb = status_history("squeue_next_#{arch}", range).collect do |time, value|
      clow = low[time] || 0
      [time * 1000, clow + value]
    end

    data['squeue_low'] = comb
    max = add_arrays(data['squeue_high'], data['squeue_med']).map { |_, value| value }.max || 0
    data['events_max'] = max * 2
    data['jobs_max'] = maximumvalue(data['waiting']) * 2

    render json: data
  end

  def old; end

  private

  def status_history(key, range)
    user_range = [HOURS_IN_ONE_YEAR, range.to_i].min
    Rails.cache.fetch("#{key}-#{user_range}", expires_in: user_range.to_i.hours / 150) do
      StatusHistory.history_by_key_and_hours(key, user_range).sort_by { |a| a[0] }
    end
  end

  def set_default_architecture
    @default_architecture = 'x86_64'
  end

  def fetch_workerstatus
    @workerstatus = Xmlhash.parse(WorkerStatus.hidden.to_xml)
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
