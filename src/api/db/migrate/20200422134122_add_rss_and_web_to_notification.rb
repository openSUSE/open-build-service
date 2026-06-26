class AddRssAndWebToNotification < ActiveRecord::Migration[6.0]
  def up
    safety_assured do
      add_column :notifications, :rss, :boolean, default: false
      add_column :notifications, :web, :boolean, default: false
    end
  end

  def down
    safety_assured do
      remove_column :notifications, :rss
      remove_column :notifications, :web
    end
  end
end
