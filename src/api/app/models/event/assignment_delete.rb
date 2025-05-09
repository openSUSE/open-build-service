module Event
  class AssignmentDelete < Assignment
    self.description = 'Unassigned a user from a package.'
    self.notification_explanation = 'Receive notifications for unassignments.'

    def subject
      "#{payload['assignee']} unassigned from the package #{payload['project']}/#{payload['package']} by #{payload['assigner']}"
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
