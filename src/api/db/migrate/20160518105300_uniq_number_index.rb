class UniqNumberIndex < ActiveRecord::Migration
  def self.up
    remove_index :bs_requests, :number
    add_index :bs_requests, :number, unique: true
  end

  def self.down
    remove_index :bs_requests, :number
    add_index :bs_requests, :number
  end
end
