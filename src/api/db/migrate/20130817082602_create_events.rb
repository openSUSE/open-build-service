class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :eventtype, null: false
      t.text :payload
      t.boolean :queued, default: false, null: false
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
  end
end
