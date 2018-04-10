# frozen_string_literal: true
class UpdateReleasedBinariesJob < CreateJob
  queue_as :releasetracking

  def perform(event_id)
    event = Event::Base.find(event_id)
    pl = event.payload
    repo = Repository.find_by_project_and_name(pl['project'], pl['repo'])
    return unless repo
    BinaryRelease.update_binary_releases(repo, pl['payload'], event.created_at)
  end
end
