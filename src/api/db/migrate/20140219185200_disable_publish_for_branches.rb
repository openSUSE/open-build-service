class DisablePublishForBranches < ActiveRecord::Migration
  def self.up
    add_column :configurations, :disable_publish_for_branches, :boolean, default: true
  end

  def self.down
    remove_column :configurations, :disable_publish_for_branches
  end
end
