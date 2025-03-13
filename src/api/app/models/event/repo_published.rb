module Event
  class RepoPublished < Base
    include EventObjectRepository

    self.message_bus_routing_key = 'repo.published'
    self.description = 'Repository published'
    payload_keys :project, :repo, :buildid

    private

    def clear_caches
      # TODO: We should touch the repository instead of deleting the key
      # to invalidate the cache. However, repository currently does not have
      # an updated_at column so we can not use Rails' cache_key method.
      project_name = payload['project']
      repository_name = payload['repo']
      Rails.cache.delete("build_id-#{project_name}-#{repository_name}")
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(16777215)
#  undone_jobs :integer          default(0)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
