class RenameRepoArchs < ActiveRecord::Migration
  def self.up
    rename_table :architectures_repositories, :repository_architectures
  end

  def self.down
    rename_table :repository_architectures, :architectures_repositories
  end
end
