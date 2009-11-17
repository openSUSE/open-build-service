class ChangeNamesToBinary < ActiveRecord::Migration
  def self.up
	remove_index "db_projects", :name => "projects_name_index"
	change_column :db_projects, :name, :binary, :limit => 255
	# not supported by rails add_index "db_projects", ["name"], :name => "projects_name_index", :unique => true, :limit => 255
	execute "CREATE UNIQUE INDEX projects_name_index ON db_projects (name(255));"
        
  end

  def self.down
	change_column :db_projects, :name, :string
  end
end
