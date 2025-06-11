module Event
  class CommentForReport < Base
    include CommentEvent

    self.message_bus_routing_key = 'report.comment'
    self.description = 'New comment for report created'
    payload_keys :report_id, :reporter, :reportable_id, :reportable_type, :reason, :category

    self.notification_explanation = 'Receive notifications for comments created on a report for which you are...'

    def subject
      "New comment in report ##{payload['report_id']}"
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
