namespace :watchlist do
  desc 'Create a list of emails which should be used to warn users'
  task list_users_to_warn: :environment do
    users_emails = []
    # Retrieve the emails from users which, having projects in the new watchlist, also
    # have some project in the old watch list which aren't in the new watchlist.
    User.where(id: WatchedItem.where(watchable_type: :project).map(&:user_id).uniq).each do |user|
      watched_project_items = user.watched_items.where(watchable_type: :project).map(&:watchable)
      next if watched_project_items.length.zero?

      watched_projects = user.watched_projects.map(&:project)
      extra = watched_projects - watched_project_items
      next if extra.length.zero?

      users_emails.push(user.email)
    end
    puts 'List of emails to send the warn of the watchlist migration: ' + users_emails.join(',')
  end

  desc 'Copy projects from the old watchlist to the new one'
  task migrate: :environment do
    # Copy projects from the old watchlist to the new one only if the user has projects
    # in the old wachtlist and the user doesn't have any project in the new watchlist.
    User.where(id: WatchedProject.all.map(&:user_id).uniq).each do |user|
      next if user.watched_items.where(watchable_type: :project).any?

      user.watched_projects.each do |watched_project|
        WatchedItem.find_or_create_by(user: user, watchable: watched_project.project)
      end
    end
  end
end
