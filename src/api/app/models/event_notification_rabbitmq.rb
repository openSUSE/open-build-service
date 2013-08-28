class EventNotificationRabbitmq

  def initialize(event)
    @event = event
  end

  def send
    return true unless CONFIG['rabbitmq_server']
    require 'bunny'

    args = @event.payload
    type = @event.class.raw_type || "UNKNOWN"

    # TODO: come from configuration
    prefix = "OBS"
    type = "#{prefix}_#{type}"

    args['eventtype'] = type
    args['time'] = @event.created_at

    begin
      conn = Bunny.new host: CONFIG['rabbitmq_server'], vhost: "mailer_vhost", user: "mailer", password: "mailerpwd"
      conn.start

      ch = conn.create_channel
      x = ch.direct("mailer_exchange")
      q = ch.queue("", auto_delete: true).bind(x, routing_key: 'mailer')
      q.subscribe do |delivery_info, properties, payload|
        Rails.logger.debug "Received #{payload}"
      end
      x.publish(Yajl::Encoder.encode(args, routing_key: 'mailer'))
      conn.close
    rescue Bunny::Exception
      false
    end
    true
  end

end