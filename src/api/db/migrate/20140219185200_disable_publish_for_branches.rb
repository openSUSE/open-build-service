# frozen_string_literal: true
class DisablePublishForBranches < ActiveRecord::Migration[4.2]
  def self.up
    add_column :configurations, :disable_publish_for_branches, :boolean, default: true
  end

  def self.down
    remove_column :configurations, :disable_publish_for_branches
  end
end
