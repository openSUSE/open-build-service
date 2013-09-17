class AddQueuedIndex < ActiveRecord::Migration
  def change
    add_index :events, :queued
  end
end
