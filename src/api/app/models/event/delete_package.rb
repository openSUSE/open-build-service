module Event
  class DeletePackage < Base
    self.description = 'Package was deleted'
    payload_keys :project, :package, :sender, :comment, :requestid
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      'package.delete'
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] if attribs['comment'].present?
      super(attribs, keys)
    end

    private

    def metric_tags
      { project: payload['project'], package: payload['package'], home: ::Project.home?(payload['project']) }
    end

    def metric_fields
      { count: Package.count }
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :integer          not null, primary key
#  eventtype   :string(255)      not null, indexed
#  payload     :text(65535)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#  undone_jobs :integer          default(0)
#  mails_sent  :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
