class PatchinfoRequiresIssue < ActiveRecord::Migration
  def up
    add_column :channel_targets, :requires_issue, :boolean
  end

  def down
    remove_column :channel_targets, :requires_issue
  end
end
