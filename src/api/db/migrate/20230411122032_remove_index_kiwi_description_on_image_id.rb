class RemoveIndexKiwiDescriptionOnImageId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'kiwi_descriptions', 'image_id', name: 'index_kiwi_descriptions_on_image_id'
  end
end
