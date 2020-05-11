class AddVersionToKiwiImage < ActiveRecord::Migration[5.1]
  def change
    add_column :kiwi_images, :version, :string, default: '0.0.1'
  end
end
