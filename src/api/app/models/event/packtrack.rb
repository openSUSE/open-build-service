module Event
  class Packtrack < Base
    include EventObjectRepository

    self.message_bus_routing_key = 'repo.packtrack'
    self.description = 'Binary published'
    payload_keys :project, :repo, :payload

    # for package tracking in first place
    create_jobs :update_released_binaries_job
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
