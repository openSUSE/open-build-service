class RenameDbProjects < ActiveRecord::Migration
  def change
    rename_table :db_projects, :projects
  end
end
