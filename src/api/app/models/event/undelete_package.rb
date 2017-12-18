module Event
  class UndeletePackage < Base
    self.description = 'Package was undeleted'
    payload_keys :project, :package, :sender, :comment
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.undelete"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] if attribs['comment'].present?
      super(attribs, keys)
    end
    create_jobs :update_backend_infos_job
  end
end

# == Schema Information
#
# Table name: events
#
#  id             :integer          not null, primary key
#  eventtype      :string(255)      not null, indexed
#  payload        :text(65535)
#  created_at     :datetime         indexed
#  updated_at     :datetime
#  project_logged :boolean          default(FALSE), indexed
#  undone_jobs    :integer          default(0)
#  mails_sent     :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at      (created_at)
#  index_events_on_eventtype       (eventtype)
#  index_events_on_mails_sent      (mails_sent)
#  index_events_on_project_logged  (project_logged)
#
