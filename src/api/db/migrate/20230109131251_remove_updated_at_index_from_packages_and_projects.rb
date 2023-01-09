class RemoveUpdatedAtIndexFromPackagesAndProjects < ActiveRecord::Migration[7.0]
  def change
    remove_index :packages, column: :updated_at, name: 'updated_at_index'
    remove_index :projects, column: :updated_at, name: 'updated_at_index'
  end
end
