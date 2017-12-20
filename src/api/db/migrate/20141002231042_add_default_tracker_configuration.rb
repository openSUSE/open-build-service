class AddDefaultTrackerConfiguration < ActiveRecord::Migration[4.2]
  def self.up
    add_column :configurations, :default_tracker, :string, default: 'bnc'
  end

  def self.down
    remove_column :configurations, :default_tracker
  end
end
