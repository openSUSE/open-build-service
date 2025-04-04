module Event
  class Decision < Base
    self.abstract_class = true
    payload_keys :id, :reason, :moderator_id, :report_last_id, :reportable_type

    self.description = 'Reported content decided'
    self.notification_explanation = 'Receive notifications for report decisions.'

    receiver_roles :offender, :reporter

    def parameters_for_notification
      super.merge(notifiable_type: 'Decision', type: 'NotificationReport')
    end

    def event_object
      Report.find_by(payload['report_last_id'])
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
