# frozen_string_literal: true

class PatchinfoRequiresIssue < ActiveRecord::Migration[4.2]
  def up
    add_column :channel_targets, :requires_issue, :boolean
  end

  def down
    remove_column :channel_targets, :requires_issue
  end
end
