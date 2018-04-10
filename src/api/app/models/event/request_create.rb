# frozen_string_literal: true

module Event
  class RequestCreate < Request
    self.description = 'Request created'
    receiver_roles :source_maintainer, :target_maintainer, :source_watcher, :target_watcher
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.request.create"
    end

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
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :integer          not null, primary key
#  eventtype   :string(255)      not null, indexed
#  payload     :text(65535)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#  undone_jobs :integer          default(0)
#  mails_sent  :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
