module Event
  class ReportForPackage < Report
    self.description = 'Report for a package created'
    payload_keys :package_name, :project_name

    self.notification_explanation = 'Receive notifications for reported packages.'

    def subject
      "Package #{payload['project_name']}/#{payload['package_name']} reported"
    end

    def self.notification_link_path(notification)
      return unless Package.exists_by_project_and_name(notification.event_payload['project_name'], notification.event_payload['package_name'])

      Rails.application.routes.url_helpers.package_show_path(package: notification.event_payload['package_name'],
                                                             project: notification.event_payload['project_name'],
                                                             notification_id: notification.id)
    end

    def self.notification_link_text(payload)
      deleted_message = ' (already deleted)' unless Package.exists_by_project_and_name(payload['project_name'], payload['package_name'])
      "Report for Package #{payload['project_name']} / #{payload['package_name']}#{deleted_message}"
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
