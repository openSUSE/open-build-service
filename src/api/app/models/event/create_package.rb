module Event
  class CreatePackage < Base
    include EventObjectPackage

    self.message_bus_routing_key = 'package.create'
    self.description = 'Package created'
    payload_keys :project, :package, :sender

    def subject
      "New Package #{payload['project']}/#{payload['package']}"
    end

    private

    def metric_tags
      { home: ::Project.home?(payload['project']) }
    end

    def metric_fields
      { value: 1 }
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
