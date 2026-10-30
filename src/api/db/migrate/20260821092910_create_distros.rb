class CreateDistros < ActiveRecord::Migration[8.0]
  def change
    create_table :distros do |t|
      t.references :vendor, null: false, foreign_key: true, index: { unique: true }
      t.string :name
      t.text :description
      t.string :url

      t.timestamps
    end
  end
end
