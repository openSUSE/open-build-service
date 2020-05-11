class CreateCommitActivities < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/CreateTableWithTimestamps
  def change
    create_table :commit_activities, options: 'CHARSET=utf8 COLLATE=utf8_bin ROW_FORMAT=DYNAMIC', id: :integer do |t|
      t.date :date, null: false
      t.references :user, null: false, type: :integer
      t.string :project, null: false
      t.string :package, null: false
      t.integer :count, null: false, default: 0

      t.index [:user_id, :date]
      t.index [:date, :user_id, :project, :package], unique: true, name: 'unique_activity_day'
    end
  end
  # rubocop:enable Rails/CreateTableWithTimestamps
end
