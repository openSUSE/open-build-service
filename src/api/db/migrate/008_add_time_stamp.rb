class AddTimeStamp < ActiveRecord::Migration
  def self.up
    add_column :taggings, :created_on, :date
    add_column :taggings, :created_at, :time
    add_column :tags, :created_on, :date
    add_column :tags, :created_at, :time
  end

  def self.down
    remove_column :taggings, :created_on
    remove_column :taggings, :created_at
    remove_column :tags, :created_on
    remove_column :tags, :created_at
  end
end
