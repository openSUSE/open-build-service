class CreateWatchedItems < ActiveRecord::Migration[6.1]
  def change
    create_table :watched_items, id: :integer do |t|
      t.integer :watchable_id, null: false
      t.string :watchable_type, null: false
      t.integer :user_id, index: true
      t.timestamps
    end

    add_index :watched_items, [:watchable_type, :watchable_id], name: 'index_watched_items_on_watchable'
    add_index :watched_items, [:watchable_type, :watchable_id, :user_id], name: 'index_watched_items_on_type_id_and_user_id', unique: true
  end
end
