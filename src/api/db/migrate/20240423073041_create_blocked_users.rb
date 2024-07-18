class CreateBlockedUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :blocked_users, id: :bigint do |t|
      t.references :blocker, null: false, foreign_key: { to_table: :users }, type: :integer, index: false
      t.references :blocked, null: false, foreign_key: { to_table: :users }, type: :integer

      t.timestamps
      t.index %i[blocker_id blocked_id], unique: true
    end
  end
end
