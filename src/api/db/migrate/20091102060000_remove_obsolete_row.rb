class RemoveObsoleteRow < ActiveRecord::Migration
  def self.up
    remove_column :attrib_types, :db_namespace_id
  end

  def self.down
    # actually never used, but just for completeness
    add_column :attrib_types, :db_namespace_id, :integer
  end
end
