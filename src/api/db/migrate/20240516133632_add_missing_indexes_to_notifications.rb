class AddMissingIndexesToNotifications < ActiveRecord::Migration[7.0]
  def change
    add_index(:notifications, :created_at)
    add_index(:notifications, :delivered)
    add_index(:notifications, :event_type)
    add_index(:notifications, :rss)
    add_index(:notifications, :web)
  end
end
