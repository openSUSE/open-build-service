class CreateFlipperTables < ActiveRecord::Migration[5.2]
  def change
    create_table :flipper_features, options: 'CHARSET=utf8 COLLATE=utf8_bin ROW_FORMAT=DYNAMIC', id: :integer do |t|
      t.string :key, null: false
      t.timestamps null: false

      t.index :key, unique: true
    end

    create_table :flipper_gates, options: 'CHARSET=utf8 COLLATE=utf8_bin ROW_FORMAT=DYNAMIC', id: :integer do |t|
      t.string :feature_key, null: false
      t.string :key, null: false
      t.string :value
      t.timestamps null: false

      t.index [:feature_key, :key, :value], unique: true
    end
  end
end
