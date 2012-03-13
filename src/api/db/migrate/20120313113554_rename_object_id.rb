class RenameObjectId < ActiveRecord::Migration
  def self.up
    rename_column :messages, :object_id, :db_object_id
    rename_column :ratings, :object_id, :db_object_id
    rename_column :ratings, :object_type, :db_object_type
    rename_column :messages, :object_type, :db_object_type
  end

  def self.down
    rename_column :messages, :db_object_id, :object_id
    rename_column :ratings, :db_object_id, :object_id
    rename_column :messages, :db_object_type, :object_type
    rename_column :ratings, :db_object_type, :object_type
  end
end
