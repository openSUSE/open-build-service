# frozen_string_literal: true

require 'builder'

class IssueTrackerWriteToBackendJob < ApplicationJob
  queue_as :quick

  def perform
    logger.debug 'Write issue tracker information to backend...'
    Backend::Api::IssueTrackers.write_list(IssueTracker.all.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS))
  end
end
