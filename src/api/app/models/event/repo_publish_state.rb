class Event::RepoPublishState < Event::Base
  self.raw_type = 'REPO_PUBLISH_STATE'
  self.description = 'Publish State of Repository has changed'
  payload_keys :project, :repo, :state
end

