class PublishIssues < ActiveRecord::Migration[6.0]
  def change
    add_column :issue_trackers, :publish_issues, :boolean, default: true
  end
end
