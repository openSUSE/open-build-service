# frozen_string_literal: true

class AddChannelTargetDisableOption < ActiveRecord::Migration[4.2]
  def self.up
    add_column :channel_targets, :disabled, :boolean, default: false
  end

  def self.down
    remove_column :channel_targets, :disabled
  end
end
