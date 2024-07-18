module Event
  class FavoredDecision < Base
    receiver_roles :reporter, :offender
    self.description = 'Reported content favored'

    payload_keys :id, :reason, :moderator_id, :report_last_id, :reportable_type

    self.notification_explanation = 'Receive notifications for favored report decisions.'

    def subject
      decision = Decision.find(payload['id'])
      "Favored #{decision.reports.first.reportable&.class&.name || decision.reports.first.reportable_type} Report".squish
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'Decision', type: 'NotificationReport')
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
