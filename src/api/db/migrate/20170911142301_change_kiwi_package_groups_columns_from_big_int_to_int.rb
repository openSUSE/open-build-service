# frozen_string_literal: true

class ChangeKiwiPackageGroupsColumnsFromBigIntToInt < ActiveRecord::Migration[5.1]
  def up
    change_column :kiwi_package_groups, :id, :integer, auto_increment: true
    change_column :kiwi_package_groups, :image_id, :integer
  end

  def down
    change_column :kiwi_package_groups, :id, :bigint, auto_increment: true
    change_column :kiwi_package_groups, :image_id, :bigint
  end
end
