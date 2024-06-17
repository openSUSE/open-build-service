class UpdateReleasedBinariesJob < CreateJob
  queue_as :releasetracking

  def perform(event_id)
    event = Event::Base.find(event_id)

    repo = Repository.find_by_project_and_name(event.payload['project'], event.payload['repo'])
    return unless repo

    BinaryRelease.update_binary_releases(repo, event.payload['payload'], event.created_at)
  end
end
