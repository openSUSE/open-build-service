class AddPackagesKiwiImageIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :packages, %w[kiwi_image_id], name: :index_packages_kiwi_image_id, unique: true
  end
end
