class AddApiKeyToIssueTracker < ActiveRecord::Migration[7.0]
  def change
    add_column :issue_trackers, :api_key, :string
  end
end
