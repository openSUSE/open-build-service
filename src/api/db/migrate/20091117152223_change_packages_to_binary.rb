class ChangePackagesToBinary < ActiveRecord::Migration

  def self.up
        remove_index "db_packages", :name => "packages_all_index"
        change_column :db_packages, :name, :binary, :limit => 255
        # not supported by rails add_index "db_packages", ["name"], :name => "packages_all_index", :unique => true, :limit => 255
        execute "CREATE UNIQUE INDEX packages_all_index ON db_packages (name(255));"

  end

  def self.down
        change_column :db_packages, :name, :string
  end

end
