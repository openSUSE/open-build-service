class AddTimeStamp < ActiveRecord::Migration
  def self.up
    add_column :taggings, :created_at, :datetime
    add_column :tags, :created_at, :datetime
  end

  def self.down
    remove_column :taggings, :created_at
    remove_column :tags, :created_at
  end
end
