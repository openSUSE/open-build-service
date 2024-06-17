class UpdateReleasedBinariesJob < CreateJob
  queue_as :releasetracking

  def perform(event_id)
    event = Event::Base.find(event_id)

    repo = Repository.find_by_project_and_name(event.payload['project'], event.payload['repo'])
    return unless repo

    update_binary_releases(repo, event.payload['payload'], event.created_at)
  end

  private

  def update_binary_releases(repository, key, time = Time.now)
    begin
      notification_payload = ActiveSupport::JSON.decode(Backend::Api::Server.notification_payload(key))
    rescue Backend::NotFoundError
      logger.error("Payload got removed for #{key}")
      return
    end
    BinaryRelease.update_binary_releases_via_json(repository, notification_payload, time)
    Backend::Api::Server.delete_notification_payload(key)
  end
end
