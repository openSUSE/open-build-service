class ProductMediumTracking < ActiveRecord::Migration
  def up
    add_column :binary_releases, :medium, :string
  end

  def down
    remove_column :binary_releases, :medium
  end
end
