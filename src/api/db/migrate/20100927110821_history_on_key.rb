class HistoryOnKey < ActiveRecord::Migration
  def self.up
	add_index 'status_histories', ['key']
  end

  def self.down
	remove_index 'status_histories', :column => ['key']
  end
end
