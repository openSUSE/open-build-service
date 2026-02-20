module Event
  class UpstreamPackageVersionChanged < Base
    self.description = 'Version of the upstream package has changed'
    self.message_bus_routing_key = 'package.upstream_version_changed'
    self.notification_explanation = 'Receive a notification when a new upstream version is available for a package you are involved with (as a develpackage maintainer or as maintainer).'

    payload_keys :upstream_version, :project, :package

    receiver_roles :develpackage_or_package_maintainer

    def self.notification_feature_flag
      :package_version_tracking
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'Package',
                  notifiable_id: ::Package.find_by_project_and_name(payload['project'], payload['package'])&.id,
                  type: 'NotificationPackage')
    end

    def subject
      "Upstream version changed for #{payload['project']}/#{payload['package']} to #{payload['upstream_version']}"
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
