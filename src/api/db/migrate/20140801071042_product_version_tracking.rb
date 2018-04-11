# frozen_string_literal: true

class ProductVersionTracking < ActiveRecord::Migration[4.2]
  def up
    add_column :products, :version, :string
    add_column :products, :baseversion, :string
    add_column :products, :patchlevel, :string
    add_column :products, :release, :string

    rename_column :product_media, :medium, :name
  end

  def down
    remove_column :products, :version
    remove_column :products, :baseversion
    remove_column :products, :patchlevel
    remove_column :products, :release

    rename_column :product_media, :name, :medium
  end
end
