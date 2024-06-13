module Event
  class RelationshipCreate < Relationship
    self.message_bus_routing_key = 'relationship.create'
    self.description = 'Relationship created'

    receiver_roles :any_role

    self.notification_explanation = "Receive notifications when someone adds you or your group to a project or package with any of these roles: #{Role.local_roles.to_sentence}."

    def subject
      object = payload['project']
      object += "/#{payload['package']}" if payload['package']
      "#{payload['who']} added you as #{payload['role']} on #{object}"
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
