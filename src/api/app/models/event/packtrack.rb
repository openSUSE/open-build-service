class Event::Packtrack < Event::Base
  self.raw_type = 'PACKTRACK'
  self.description = 'Binary was published'
  payload_keys :project, :repo, :payload

  # for package tracking in first place
  create_jobs :update_released_binaries
end

