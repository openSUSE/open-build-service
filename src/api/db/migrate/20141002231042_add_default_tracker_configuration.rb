class AddDefaultTrackerConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :default_tracker, :string, default: "bnc"
  end

  def self.down
    remove_column :configurations, :default_tracker
  end
end
