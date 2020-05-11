class ProductVersionTracking < ActiveRecord::Migration[4.2]
  def up
    add_column :products, :version, :string
    add_column :products, :baseversion, :string
    add_column :products, :patchlevel, :string
    add_column :products, :release, :string

    execute 'ALTER TABLE `product_media` CHANGE `medium` `name` varchar(255) CHARSET utf8 DEFAULT NULL'
  end

  def down
    remove_column :products, :version
    remove_column :products, :baseversion
    remove_column :products, :patchlevel
    remove_column :products, :release

    rename_column :product_media, :name, :medium
  end
end
