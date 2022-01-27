# frozen_string_literal: true

class AddWordBoundaryToIssueTrackerRegex < ActiveRecord::Migration[6.1]
  def up
    IssueTracker.unscoped.each do |issue_tracker|
      current_regex = issue_tracker.regex
      issue_tracker.update(regex: "\\b#{current_regex}\\b")
      sleep(0.01)
    end
  end

  def down
    IssueTracker.unscoped.each do |issue_tracker|
      current_regex = issue_tracker.regex
      previous_regex = current_regex.delete('\b')
      issue_tracker.update(regex: previous_regex)
      sleep(0.01)
    end
  end
end
