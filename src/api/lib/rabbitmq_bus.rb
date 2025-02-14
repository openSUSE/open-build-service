class RabbitmqBus
  cattr_accessor :connection, :exchange, :failed

  def self.send_to_bus(channel, data)
    channel = "#{Configuration.amqp_namespace}.#{channel}"
    publish(channel, data)
  rescue Bunny::Exception => e
    Rails.logger.error "Publishing to AMQP failed, automatic recovery too: #{e.message}"
    Airbrake.notify(e)
  end

  def self.publish(event_routing_key, event_payload)
    return unless CONFIG['amqp_options']

    start_connection
    wrapped_exchange.publish(event_payload, routing_key: event_routing_key)
  end

  # Start one connection, channel and exchange per rails process
  # and reuse them
  def self.wrapped_exchange
    return exchange if exchange

    connection.start
    rabbitmq_channel = connection.create_channel
    self.exchange = if CONFIG['amqp_exchange_name']
                      rabbitmq_channel.exchange(CONFIG['amqp_exchange_name'], CONFIG['amqp_exchange_options'].try(:symbolize_keys) || {})
                    else
                      # can't cover due to https://github.com/arempe93/bunny-mock/pull/25
                      # :nocov:
                      rabbitmq_channel.default_exchange
                      # :nocov:
                    end
  end

  # this function is skipped in tests by putting a BunnyMock in self.connection
  def self.start_connection
    # :nocov:
    self.connection ||= Bunny.new(CONFIG['amqp_options'].try(:symbolize_keys))
    # :nocov:
  end
  private_class_method :start_connection
end
