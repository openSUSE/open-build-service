# frozen_string_literal: true

class UpdateCveIssueTracker < ActiveRecord::Migration[7.2]
  def up
    cve_issue_tracker = IssueTracker.find_by(name: 'cve')
    return unless cve_issue_tracker

    # rubocop:disable Rails/SkipsModelValidations
    cve_issue_tracker.update_columns(url: 'https://www.cve.org', show_url: 'https://www.cve.org/CVERecord?id=@@@')
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
