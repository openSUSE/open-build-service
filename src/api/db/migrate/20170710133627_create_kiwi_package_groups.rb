# frozen_string_literal: true

class CreateKiwiPackageGroups < ActiveRecord::Migration[5.1]
  def change
    create_table :kiwi_package_groups do |t|
      t.integer :kiwi_type, null: false
      t.string :profiles
      t.string :pattern_type
      t.belongs_to :image, index: true

      t.timestamps
    end
  end
end
