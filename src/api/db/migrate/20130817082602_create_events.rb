class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :eventtype, null: false
      t.text :payload
      t.timestamps
    end
  end
end
