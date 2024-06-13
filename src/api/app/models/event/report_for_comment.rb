module Event
  class ReportForComment < Report
    self.description = 'Report for a comment created'
    payload_keys :commentable_type, :bs_request_number, :bs_request_action_id,
                 :project_name, :package_name, :commenter

    self.notification_explanation = 'Receive notifications for reported comments.'

    def subject
      "Comment by #{payload['commenter']} reported"
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
