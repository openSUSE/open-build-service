class CreateJoinTableNotificationsProjects < ActiveRecord::Migration[6.0]
  def change
    create_join_table :notifications, :projects, column_options: { type: :integer, null: false } do |t|
      t.index :notification_id
      t.index [:notification_id, :project_id], unique: true
    end
  end
end
