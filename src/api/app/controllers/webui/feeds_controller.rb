class Webui::FeedsController < Webui::WebuiController

  include Webui::WebuiHelper
  include StatisticsCalculations

  layout false

  def news
    @news = StatusMessage.alive.limit(5)
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime::RSS
  end

  def latest_updates
    raise ActionController::RoutingError.new('expected application/rss') unless request.format == Mime::RSS
    @latest_updates = get_latest_updated(10)
  end

  def commits
    @project = Project.find_by_name(params[:project])
    if @project.nil?
      render(file: Rails.root.join('public/404'), status: 404, layout: false, formats: [:html])
      return
    end
    # The sourceaccess flag is checked for the project, but not for every package
    if !User.current.is_admin? && @project.disabled_for?('sourceaccess', nil, nil)
      render file: Rails.root.join('public/403'), formats: [:html], status: :forbidden, layout: false
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
