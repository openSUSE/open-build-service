class CreateVendors < ActiveRecord::Migration[8.0]
  def change
    create_table :vendors do |t|
      t.references :project, null: false, foreign_key: true, type: :int, index: { unique: true }
      t.string :name
      t.text :description
      t.string :url

      t.timestamps
    end
  end
end
