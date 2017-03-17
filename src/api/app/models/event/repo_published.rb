class Event::RepoPublished < Event::Base
  self.raw_type = 'REPO_PUBLISHED'
  self.description = 'Repository was published'
  payload_keys :project, :repo
end

