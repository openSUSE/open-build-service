class ChangeKiwiPackagesColumnsFromBigIntToInt < ActiveRecord::Migration[5.1]
  def up
    change_column :kiwi_packages, :id, :integer
    change_column :kiwi_packages, :package_group_id, :integer
  end

  def down
    change_column :kiwi_packages, :id, :bigint
    change_column :kiwi_packages, :package_group_id, :bigint
  end
end
