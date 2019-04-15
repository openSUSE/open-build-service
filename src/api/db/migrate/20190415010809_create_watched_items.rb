class CreateWatchedItems < ActiveRecord::Migration[5.2]
  def change
    create_table :watched_items, id: :integer do |t|
      t.belongs_to :watchable, polymorphic: true
      t.timestamps
    end
  end
end
