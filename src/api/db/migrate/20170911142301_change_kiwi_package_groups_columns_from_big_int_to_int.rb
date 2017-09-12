class ChangeKiwiPackageGroupsColumnsFromBigIntToInt < ActiveRecord::Migration[5.1]
  def up
    change_column :kiwi_package_groups, :id, :integer
    change_column :kiwi_package_groups, :image_id, :integer
  end

  def down
    change_column :kiwi_package_groups, :id, :bigint
    change_column :kiwi_package_groups, :image_id, :bigint
  end
end
