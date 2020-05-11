class CreateKiwiPreferenceTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :kiwi_preference_types, id: :integer do |t|
      t.references :image, type: :integer
      t.integer :image_type
      t.string :containerconfig_name
      t.string :containerconfig_tag
    end
  end
end
