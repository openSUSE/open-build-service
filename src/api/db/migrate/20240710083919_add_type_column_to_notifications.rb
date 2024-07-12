class AddTypeColumnToNotifications < ActiveRecord::Migration[7.0]
  def change
    add_column :notifications, :type, :string
    add_index :notifications, :type
  end
end
