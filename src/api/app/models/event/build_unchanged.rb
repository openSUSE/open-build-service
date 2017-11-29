class Event::BuildUnchanged < Event::Build
  self.description = 'Package has succeeded building with unchanged result'
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.package.build_unchanged"
  end
end
