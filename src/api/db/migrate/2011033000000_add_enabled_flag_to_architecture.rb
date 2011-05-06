# Enabled architectures should match the configured backend schedulers

class AddEnabledFlagToArchitecture < ActiveRecord::Migration
  def self.up
    add_column :architectures, :enabled, :boolean, :default => false
  end

  def self.down
    remove_column :architectures, :enabled
  end
end
