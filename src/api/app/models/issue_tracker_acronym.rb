class IssueTrackerAcronym < ActiveRecord::Base
  belongs_to :issue_tracker

  validates_presence_of :issue_tracker_id, :name
  validates_uniqueness_of :name
end

