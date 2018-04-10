# frozen_string_literal: true
class AddForeignKeyConstraintsToKiwiTables < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :kiwi_package_groups, :kiwi_images, column: :image_id
    add_foreign_key :kiwi_packages, :kiwi_package_groups, column: :package_group_id
  end
end
