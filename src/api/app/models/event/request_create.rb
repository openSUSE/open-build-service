class Event::RequestCreate < Event::Request
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
    base.merge({'Message-ID' => my_message_number})
  end

  def subject
    "Request #{payload['number']} created by #{payload['who']} (#{actions_summary})"
  end

  def expanded_payload
    payload_with_diff
  end
end
