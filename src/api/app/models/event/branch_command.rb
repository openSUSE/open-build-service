module Event
  class BranchCommand < Package
    self.description = 'Package was branched'
    payload_keys :targetproject, :targetpackage, :user
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.branch"
    end

    def subject
      "Package Branched: #{payload['project']}/#{payload['package']} => #{payload['targetproject']}/#{payload['targetpackage']}"
    end
  end
end
