class AddMergingAttributeToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :merging, :boolean, default: false
  end
end
