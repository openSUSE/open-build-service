class AddAnityaPrereleaseToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :anitya_prerelease, :boolean, null: false, default: false
  end
end
