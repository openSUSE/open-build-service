class CreateDisabledRepos < ActiveRecord::Migration
  def self.up
    create_table :disabled_repos do |t|
      t.column :db_package_id, :integer, :null => false
      t.column :repository_id, :integer
      t.column :architecture_id, :integer
    end

    add_index "disabled_repos", ["db_package_id", "repository_id", "architecture_id"], :name => "package_repo_arch_index", :unique => true
  end

  def self.down
    drop_table :disabled_repos
  end
end
