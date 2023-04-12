class AddKiwiDescriptionsImageIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :kiwi_descriptions, %w[image_id], name: :index_kiwi_descriptions_image_id, unique: true
  end
end
