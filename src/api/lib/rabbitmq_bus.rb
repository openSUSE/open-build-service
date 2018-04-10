# frozen_string_literal: true

class RabbitmqBus
  def self.publish(event_routing_key, event_payload)
    return unless CONFIG['amqp_options']
    start_connection

    $rabbitmq_exchange.publish(event_payload, routing_key: event_routing_key)
  end

  # Start one connection, channel and exchange per rails process
  # and reuse them
  def self.start_connection
    $rabbitmq_conn ||= Bunny.new(CONFIG['amqp_options'].try(:symbolize_keys))
    $rabbitmq_conn.start
    $rabbitmq_channel ||= $rabbitmq_conn.create_channel
    $rabbitmq_exchange = if CONFIG['amqp_exchange_name']
      $rabbitmq_channel.exchange(CONFIG['amqp_exchange_name'], CONFIG['amqp_exchange_options'].try(:symbolize_keys) || {})
    else
      $rabbitmq_channel.default_exchange
    end
  end
  private_class_method :start_connection
end
