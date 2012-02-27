class RenameIssueTableColumns < ActiveRecord::Migration
  def self.up
    rename_column :issues, :description, :summary
    rename_column :issue_trackers, :long_name, :label
    Issue.reset_column_information
  end

  def self.down
    rename_column :issues, :summary, :description
    rename_column :issue_trackers, :label, :long_name
    Issue.reset_column_information
  end
end
