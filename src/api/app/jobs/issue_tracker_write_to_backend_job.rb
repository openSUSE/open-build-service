require 'builder'

class IssueTrackerWriteToBackendJob < ApplicationJob
  queue_as :quick

  def perform
    path = "/issue_trackers"
    logger.debug "Write issue tracker information to backend..."
    Backend::Connection.put(path, IssueTracker.all.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS))
  end
end
