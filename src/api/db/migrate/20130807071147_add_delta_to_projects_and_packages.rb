class AddDeltaToProjectsAndPackages < ActiveRecord::Migration
  def change
    add_column :projects, :delta, :boolean, default: true, null: false
    add_column :packages, :delta, :boolean, default: true, null: false
  end
end
