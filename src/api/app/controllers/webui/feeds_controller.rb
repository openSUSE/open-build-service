class Webui::FeedsController < Webui::WebuiController
  include StatisticsCalculations

  layout false
  before_action :set_project, only: ['commits']

  def news
    @news = StatusMessage.alive.limit(5)
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime[:rss]
  end

  def latest_updates
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime[:rss]
    @latest_updates = get_latest_updated(10)
  end

  def commits
    # The sourceaccess flag is checked for the project, but not for every package
    if !User.current.is_admin? && @project.disabled_for?('sourceaccess', nil, nil)
      redirect_to '/403.html', status: :forbidden
      return
    end
    unless params[:starting_at].blank?
      @start = (Time.zone.parse(params[:starting_at]) rescue nil)
    end
    @start ||= 7.days.ago
    @finish = nil
    unless params[:ending_at].blank?
      @finish = (Time.zone.parse(params[:ending_at]) rescue nil)
    end
    @commits = @project.project_log_entries.where(event_type: 'commit').where(["datetime >= ?", @start])
    @commits = @commits.where(["datetime <= ?", @finish]) unless @finish.nil?
    @commits = @commits.order("datetime desc")
  end
end
