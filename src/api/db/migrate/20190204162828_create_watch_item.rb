class CreateWatchItem < ActiveRecord::Migration[5.2]
  def change
    create_table :watch_items do |t|
      t.references :user, index: true
      t.integer :item_id
      t.string :item_type

      t.timestamps
    end
  end
end
