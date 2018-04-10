# frozen_string_literal: true
class UniqNumberIndex < ActiveRecord::Migration[4.2]
  def self.up
    remove_index :bs_requests, :number
    add_index :bs_requests, :number, unique: true
  end

  def self.down
    remove_index :bs_requests, :number
    add_index :bs_requests, :number
  end
end
