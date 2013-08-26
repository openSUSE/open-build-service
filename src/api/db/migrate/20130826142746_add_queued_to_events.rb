class AddQueuedToEvents < ActiveRecord::Migration
  def change
    add_column :events, :queued, :boolean, :default => false, :null => false
  end
end
