require 'statistics_calculations'

class Webui::MainController < Webui::WebuiController
  skip_before_action :check_anonymous, only: [:index]

  def gather_busy
    busy = []
    archs = Architecture.where(available: 1).pluck(:name).map { |arch| map_to_workers(arch) }.uniq
    archs.each do |arch|
      starttime = Time.now.to_i - 168.to_i * 3600
      rel = StatusHistory.where("time >= ? AND \`key\` = ?", starttime, 'building_' + arch)
      values = rel.pluck(:time, :value).collect { |time, value| [time.to_i, value.to_f] }
      values = StatusHelper.resample(values, 400)
      if busy.empty?
        busy = values
      elsif values.present?
        busy = Webui::MonitorController.addarrays(busy, values)
      end
    end
    busy
  end

  def index
    @status_messages = StatusMessage.alive.includes(:user).limit(4).to_a
    @workerstatus = Rails.cache.fetch('workerstatus_hash', expires_in: 10.minutes) do
      WorkerStatus.hidden.to_hash
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

    switch_to_webui2
  end
end
