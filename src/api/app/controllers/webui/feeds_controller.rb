require 'statistics_calculations'

class Webui::FeedsController < Webui::WebuiController
  layout false
  before_action :set_project, only: [:commits]
  before_action :set_timerange, only: [:commits]

  def news
    @news = StatusMessage.newest.for_current_user.includes(:user).limit(5)
  end

  def latest_updates
    @latest_updates = StatisticsCalculations.get_latest_updated(10)
  end

  def commits
    authorize @project, :source_access?

    @terse = params[:terse].present?

    commits = @project.project_log_entries.where(event_type: 'commit').where(datetime: @start..)
    commits = commits.where(datetime: ..@finish) if @finish.present?
    @commits = commits.order('datetime desc')
  end

  def notifications
    @user = User.find_by!(rss_secret: params[:secret])
    @host = ::Configuration.obs_url
    @configuration = ::Configuration.fetch
    @notifications = @user.combined_rss_feed_items
  end

  private

  def set_timerange
    start = params.fetch(:starting_at, 7.days.ago.to_s)
    @start = Time.zone.parse(start)
    finish = params['ending_at']
    @finish = Time.zone.parse(finish) if finish
  # Ignore params if the date string is invalid...
  rescue ArgumentError
    @start = 7.days.ago
    @finish = nil
  end
end
