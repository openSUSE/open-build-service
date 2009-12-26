class MoreIndexes < ActiveRecord::Migration
  def self.up
	add_index 'status_histories', ['time', 'key']
  end

  def self.down
	remove_index 'status_histories', :column => ['time', 'key']
  end
end
