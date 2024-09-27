class ChangeReportBugUrlToString < ActiveRecord::Migration[7.0]
  def up
    safety_assured do
      change_column :packages, :report_bug_url, :string, limit: 8192
      change_column :projects, :report_bug_url, :string, limit: 8192
    end
  end

  def down
    safety_assured do
      change_column :packages, :report_bug_url, :text
      change_column :projects, :report_bug_url, :text
    end
  end
end
