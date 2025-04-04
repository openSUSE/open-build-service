module Event
  class Report < Base
    receiver_roles :moderator
    self.description = 'Report for inappropriate content created'
    self.notification_explanation = 'Receive notifications for reports.'

    payload_keys :id, :reporter, :reportable_id, :reportable_type, :reason, :category

    def subject
      raise AbstractMethodCalled
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'Report', type: 'NotificationReport')
    end

    def event_object
      ::Report.find_by(payload['report_last_id'])
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
