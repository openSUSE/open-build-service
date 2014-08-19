class ProductVersionTracking < ActiveRecord::Migration
  def up
    add_column :products, :version, :string
    add_column :products, :baseversion, :string
    add_column :products, :patchlevel, :string
    add_column :products, :release, :string
  end

  def down
    remove_column :products, :version
    remove_column :products, :baseversion
    remove_column :products, :patchlevel
    remove_column :products, :release
  end
end
