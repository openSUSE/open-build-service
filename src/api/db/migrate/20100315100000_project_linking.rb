class ProjectLinking < ActiveRecord::Migration
  def self.up
    create_table "linked_projects" do |t|
      t.column "db_project_id", :integer, :null => false
      t.column "linked_db_project_id", :integer, :null => false
    end
    add_index "linked_projects", ["db_project_id", "linked_db_project_id"], :name => "linked_projects_index", :unique => true
  end

  def self.down
    drop_table "linked_projects"
  end
end
