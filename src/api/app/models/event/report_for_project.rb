module Event
  class ReportForProject < Report
    self.description = 'Report for a project created'
    payload_keys :project_name

    self.notification_explanation = 'Receive notifications for reported projects.'

    def subject
      "Project #{payload['project_name']} reported"
    end

    def self.notification_link_path(notification)
      Rails.application.routes.url_helpers.project_show_path(notification.event_payload['project_name'], notification_id: notification.id) if Project.exists_by_name(notification.event_payload['project_name'])
    end

    def self.notification_link_text(payload)
      deleted_message = ' (already deleted)' unless Project.exists_by_name(payload['project_name'])
      "Report for Project #{payload['project_name']}#{deleted_message}"
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
