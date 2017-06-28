class Event::RepoPublished < Event::Base
  self.raw_type = 'REPO_PUBLISHED'
  self.description = 'Repository was published'
  payload_keys :project, :repo
end

# == Schema Information
#
# Table name: events
#
#  id           :integer          not null, primary key
#  eventtype    :string(255)      not null, indexed
#  payload      :text(65535)
#  queued       :boolean          default(FALSE), not null, indexed
#  lock_version :integer          default(0), not null
#  created_at   :datetime         indexed
#  updated_at   :datetime
#  undone_jobs  :integer          default(0)
#  mails_sent   :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#  index_events_on_queued      (queued)
#
