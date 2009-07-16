class RenameAttributesToAttribs < ActiveRecord::Migration
  def self.up
    rename_table :attributes, :attribs
  end

  def self.down
    rename_table :attribs, :attributes
  end
end
