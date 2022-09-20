class CopyOldWatchedProjects < ActiveRecord::Migration[6.1]
  def up
    WatchedProject.all.each do |old_watched_project|
      next if old_watched_project.user.watched_items.count.positive?

      WatchedItem.find_or_create_by(watchable: old_watched_project.project, user: old_watched_project.user)
    end
  end
end
