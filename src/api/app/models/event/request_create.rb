module Event
  class RequestCreate < Request
    self.message_bus_routing_key = 'request.create'
    self.description = 'Request created'
    receiver_roles :source_maintainer, :target_maintainer, :source_project_watcher, :target_project_watcher,
                   :source_package_watcher, :target_package_watcher

    self.notification_explanation = 'Receive notifications for requests created for projects/packages for which you are...'

    def custom_headers
      base = super
      # we're the one they mean
      base.delete('In-Reply-To')
      base.delete('References')
      base.merge('Message-ID' => my_message_number)
    end

    def subject
      "Request #{payload['number']} created by #{payload['who']} (#{actions_summary})"
    end

    def expanded_payload
      payload_with_diff
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'BsRequest', type: 'NotificationBsRequest')
    end

    private

    def metric_fields
      payload.slice('number')
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
