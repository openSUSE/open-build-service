class Webui::FeedsController < Webui::WebuiController
  include StatisticsCalculations

  layout false

  def news
    @news = StatusMessage.alive.limit(5)
    raise ActionController::RoutingError, 'expected application/rss' unless request.format == Mime[:rss]
  end

  def latest_updates
    raise ActionController::RoutingError, 'expected application/rss' unless request.format == Mime[:rss]
    @latest_updates = get_latest_updated(10)
  end
end
