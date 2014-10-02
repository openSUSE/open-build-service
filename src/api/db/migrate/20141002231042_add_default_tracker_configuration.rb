class AddDefaultTrackerConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :default_tracker, :string, :default => "boo"
  end

  def self.down
    remove_column :configurations, :default_tracker
  end
end
