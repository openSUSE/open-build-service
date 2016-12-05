class ProjectMaintains < ActiveRecord::Migration
  class OldProject < ActiveRecord::Base
     self.table_name = 'projects'
  end

  def self.up
    create_table :maintained_projects do |t|
      t.references :project, null: false
      t.integer :maintenance_project_id, null: false
    end
    execute("alter table maintained_projects add foreign key (project_id) references projects(id)")
    execute("alter table maintained_projects add foreign key (maintenance_project_id) references projects(id)")
    add_index :maintained_projects, [:project_id, :maintenance_project_id], unique: true, name: "uniq_index"

    s = OldProject.find_by_sql "SELECT id,maintenance_project_id FROM projects WHERE NOT ISNULL(maintenance_project_id)"
    s.each do |e|
      next unless Project.find_by_id e.maintenance_project_id # broken data anyway
      MaintainedProject.create(project_id: e.id, maintenance_project_id: e.maintenance_project_id)
    end

    remove_column :projects, :maintenance_project_id
  end

  def self.down
    add_column :projects, :maintenance_project_id, :integer

    MaintainedProject.all.each do |pm|
      p = Project.find_by_id(pm.maintenance_project_id)
      p.maintenance_project_id = pm.project_id
      p.save
    end

    drop_table :maintained_projects
  end
end
