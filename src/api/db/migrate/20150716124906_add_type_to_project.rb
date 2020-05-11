class AddTypeToProject < ActiveRecord::Migration[4.2]
  class TmpProject < ApplicationRecord
    self.table_name = 'projects'
  end

  class TmpDbProjectType < ApplicationRecord
    self.table_name = 'db_project_types'
  end

  def up
    execute "ALTER TABLE projects add column kind enum('standard', 'maintenance', 'maintenance_incident', 'maintenance_release') DEFAULT 'standard'"

    TmpProject.all.each do |project|
      project_type = TmpDbProjectType.find(project.type_id)
      project.kind = project_type.name
      project.save
    end
    remove_foreign_key :projects, name: 'projects_ibfk_1'
    remove_column :projects, :type_id
    drop_table :db_project_types
  end
end
