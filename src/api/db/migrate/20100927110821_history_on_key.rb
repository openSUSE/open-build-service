class HistoryOnKey < ActiveRecord::Migration
  def self.up
	add_index 'status_histories', %w(key)
  end

  def self.down
	remove_index 'status_histories', :column => %w(key)
  end
end
