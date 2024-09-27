class AddReportBugUrlToProjectsAndPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :report_bug_url, :text
    add_column :packages, :report_bug_url, :text
  end
end
