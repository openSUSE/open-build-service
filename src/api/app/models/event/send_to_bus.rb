module Event
  # performed from delayed job triggered by clockwork
  class SendToBus
    def self.connection(config)
      @@conn ||= Bunny.new(config['url'], log_level: Logger::DEBUG)
      @@conn.start
    end

    def amqp_config
      CONFIG.fetch('notifications', {}).fetch('amqp', {})
    end

    def bus_topic(config)
      # no config, nil topic
      return if config.empty? || config['url'].empty?

      ch = self.class.connection(config).create_channel
      # this has to be a predefined topic
      ch.topic(config.fetch('topic', 'pubsub'), persistent: true, passive: true)
    end

    def self.trigger_delayed_send
      new.delay.send_unsent
    end

    def send_unsent
      config = amqp_config
      t = bus_topic(config)
      Event::Base.not_sent_to_bus.find_each do |e|
        break unless e.send_to_bus(t, config)
      end
    end
  end
end
