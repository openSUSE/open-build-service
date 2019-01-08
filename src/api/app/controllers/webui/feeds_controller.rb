require 'statistics_calculations'

class Webui::FeedsController < Webui::WebuiController
  layout false
  before_action :set_project, only: ['commits']

  def news
    @news = StatusMessage.alive.includes(:user).limit(5)
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

    @start = params[:starting_at].present? ? starting_at(params[:starting_at]) : 7.days.ago
    @finish = params[:ending_at].present? ? ending_at(params[:ending_at]) : nil

    @commits = @project.project_log_entries.where(event_type: 'commit').where(['datetime >= ?', @start])
    @commits = @commits.where(['datetime <= ?', @finish]) unless @finish.nil?
    @commits = @commits.order('datetime desc')
  end

  def notifications
    token = Token::Rss.find_by_string(params[:token])
    if token
      @configuration = ::Configuration.first
      @user = token.user
      @notifications = token.user.combined_rss_feed_items
      @host = ::Configuration.obs_url
    else
      flash[:error] = 'Unknown Token for RSS feed'
      redirect_back(fallback_location: root_path)
    end
  end

  private

  def starting_at(date)
    Time.zone.parse(date)
  rescue
    7.days.ago
  end

  def ending_at(date)
    Time.zone.parse(date)
  rescue
    nil
  end
end
