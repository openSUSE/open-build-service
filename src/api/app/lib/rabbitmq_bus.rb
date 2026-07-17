class RabbitmqBus
  cattr_accessor :session, :exchange

  def self.send_to_bus(routing_key, payload)
    return unless CONFIG['amqp_options']

    self.session ||= Bunny.new(CONFIG['amqp_options'].try(:symbolize_keys))
    wrapped_exchange.publish(payload, routing_key: "#{Configuration.amqp_namespace}.#{routing_key}")
  end

  # Start one Bunny::Session, Bunny::Channel and Bunny::Exchange per thread and reuse them
  def self.wrapped_exchange
    return exchange if exchange

    session.start
    rabbitmq_channel = session.create_channel
    self.exchange = if CONFIG['amqp_exchange_name']
                      rabbitmq_channel.exchange(CONFIG['amqp_exchange_name'], CONFIG['amqp_exchange_options'].try(:symbolize_keys) || {})
                    else
                      # can't cover due to https://github.com/arempe93/bunny-mock/pull/25
                      # :nocov:
                      rabbitmq_channel.default_exchange
                      # :nocov:
                    end
  end
end
