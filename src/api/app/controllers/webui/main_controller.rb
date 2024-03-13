require 'statistics_calculations'

class Webui::MainController < Webui::WebuiController
  skip_before_action :check_anonymous, only: [:index]

  def index
    @status_messages = StatusMessage.newest.for_current_user.includes(:user).limit(4)
    @workerstatus = Rails.cache.fetch('workerstatus_hash', expires_in: 10.minutes) do
      Xmlhash.parse(WorkerStatus.hidden.to_xml)
    end
    @latest_updates = StatisticsCalculations.get_latest_updated(6)
    @waiting_packages = 0
    @building_workers = @workerstatus.elements('building').length
    @overall_workers = @workerstatus['clients']
    @workerstatus.elements('waiting') { |waiting| @waiting_packages += waiting['jobs'].to_i }
    @busy = Rails.cache.fetch('mainpage_busy', expires_in: 10.minutes) do
      gather_busy
    end

    @system_stats = Rails.cache.fetch('system_stats_hash', expires_in: 30.minutes) do
      {
        projects: Project.count,
        packages: Package.count,
        repositories: Repository.count,
        users: User.count
      }
    end
  end

  private

  def gather_busy
    busy = []
    starttime = (Time.now.utc - 7.days).to_i
    Architecture.available.map(&:worker).uniq.each do |arch|
      rel = StatusHistory.where('time >= ? AND `key` = ?', starttime, "building_#{arch}")
      next if rel.blank?

      values = rel.pluck(:time, :value).collect { |time, value| [time.to_i, value.to_f] }
      values = StatusHelper.resample(values, 400)
      busy = if busy.blank?
               values
             else
               add_arrays(busy, values)
             end
    end
    busy
  end
end
