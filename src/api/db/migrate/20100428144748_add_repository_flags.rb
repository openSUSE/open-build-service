class AddRepositoryFlags < ActiveRecord::Migration
  def self.up
    add_column :repositories, :block,       "ENUM('all', 'local', 'never')", :null => true
    add_column :repositories, :linkedbuild, "ENUM('off', 'localdep', 'all')", :null => true
  end

  def self.down
    remove_column :repositories, :block
    remove_column :repositories, :linkedbuild
  end
end
