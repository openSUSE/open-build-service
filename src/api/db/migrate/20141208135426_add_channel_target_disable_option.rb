class AddChannelTargetDisableOption < ActiveRecord::Migration
  def self.up
    add_column :channel_targets, :disabled, :boolean, default: false
  end

  def self.down
    remove_column :channel_targets, :disabled
  end
end
