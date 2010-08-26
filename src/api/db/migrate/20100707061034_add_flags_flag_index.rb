class AddFlagsFlagIndex < ActiveRecord::Migration
  def self.up
    add_index :flags, :flag
  end

  def self.down
    remove_index :flags, :flag
  end
end
