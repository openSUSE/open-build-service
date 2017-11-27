require 'statistics_calculations'

class Webui::FeedsController < Webui::WebuiController
  layout false
  before_action :set_project, only: ['commits']

  def news
    @news = StatusMessage.alive.limit(5)
  end

  def latest_updates
    @latest_updates = StatisticsCalculations.get_latest_updated(10)
  end

  def commits
    # The sourceaccess flag is checked for the project, but not for every package
    if !User.current.is_admin? && @project.disabled_for?('sourceaccess', nil, nil)
      redirect_to '/403.html', status: :forbidden
      return
    end
    unless params[:starting_at].blank?
      @start = (begin
                  Time.zone.parse(params[:starting_at])
                rescue
                  nil
                end)
    end
    @start ||= 7.days.ago
    @finish = nil
    unless params[:ending_at].blank?
      @finish = (begin
                   Time.zone.parse(params[:ending_at])
                 rescue
                   nil
                 end)
    end
    @commits = @project.project_log_entries.where(event_type: 'commit').where(["datetime >= ?", @start])
    @commits = @commits.where(["datetime <= ?", @finish]) unless @finish.nil?
    @commits = @commits.order("datetime desc")
  end

  def notifications
    token = Token::Rss.find_by_string(params[:token])
    if token
      @configuration = ::Configuration.first
      @user = token.user
      @notifications = token.user.combined_rss_feed_items
      @host = ::Configuration.obs_url
    else
      flash[:error] = "Unknown Token for RSS feed"
      redirect_back(fallback_location: root_path)
    end
  end
end
