class Webui::WatchlistController < Webui::WebuiController
   before_action :set_project, only: [:toggle_watch]

  def toggle_watch
    User.current.watches?(@project.name) ? unwatch_item : watch_item

    if request.env['HTTP_REFERER']
      redirect_back(fallback_location: root_path)
    else
      redirect_to action: project_show_path, project: @project
    end
  end

  private

  def watch_item
    logger.debug "Add #{@project} to watchlist for #{User.current}"
    User.current.add_watched_project(@project.name)
  end

  def unwatch_item
    logger.debug "Remove #{@project} from watchlist for #{User.current}"
    User.current.remove_watched_project(@project.name)
  end
end
