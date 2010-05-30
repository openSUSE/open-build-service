class RemoveTimestampsFromStatus < ActiveRecord::Migration
  def self.up
    remove_column :status_histories, :created_at 
    remove_column :status_histories, :updated_at
  end

  def self.down
    add_column :status_histories, :created_at
    add_column :status_histories, :updated_at
  end
end
