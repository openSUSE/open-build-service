class CreateKiwiProfiles < ActiveRecord::Migration[5.2]
  def change
    create_table :kiwi_profiles, id: :integer, options: 'CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC' do |t|
      t.string :name, limit: 191, null: false
      t.string :description, limit: 191, null: false
      t.boolean :selected, null: false
      t.references :image, type: :integer, null: false, index: true

      t.timestamps

      t.index [:name, :image_id], unique: true, name: 'name_once_per_image'
    end

    add_column :kiwi_preferences, :profile, :string, limit: 191
  end
end
