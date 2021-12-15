class AddScmsyncElementsForPackagesAndProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :packages, :scmsync, :string
    add_column :projects, :scmsync, :string
  end
end
