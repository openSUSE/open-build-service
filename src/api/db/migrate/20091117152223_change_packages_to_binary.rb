class ChangePackagesToBinary < ActiveRecord::Migration

  def self.up
        remove_index "db_packages", :name => "packages_all_index"
        change_column :db_packages, :name, :binary, :limit => 255
        # add_index "db_packages", ["db_project_id", "name"], :name => "packages_all_index", :unique => true
        execute "CREATE UNIQUE INDEX packages_all_index ON db_packages (db_project_id,name(255));"

  end

  def self.down
        change_column :db_packages, :name, :string
  end

end
