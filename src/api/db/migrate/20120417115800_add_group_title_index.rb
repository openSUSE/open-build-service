class AddGroupTitleIndex < ActiveRecord::Migration
  def self.up
    add_index :groups, :title
  end

  def self.down
    remove_index :groups, :title
  end
end
