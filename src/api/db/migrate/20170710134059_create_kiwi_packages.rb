# frozen_string_literal: true

class CreateKiwiPackages < ActiveRecord::Migration[5.1]
  def change
    create_table :kiwi_packages do |t|
      t.string :name, null: false
      t.string :arch
      t.string :replaces
      t.boolean :bootinclude
      t.boolean :bootdelete
      t.belongs_to :package_group, index: true

      t.timestamps
    end
  end
end
