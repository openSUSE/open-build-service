class RemoveIndexPackagesOnKiwiImageId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'packages', 'kiwi_image_id', name: 'index_packages_on_kiwi_image_id'
  end
end
