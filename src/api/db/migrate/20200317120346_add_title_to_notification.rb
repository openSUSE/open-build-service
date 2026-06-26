class AddTitleToNotification < ActiveRecord::Migration[5.2]
  def change
    add_column :notifications, :title, :string, collation: 'utf8_unicode_ci'
  end
end
