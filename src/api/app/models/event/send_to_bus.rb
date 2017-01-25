module Event
  # performed from delayed job triggered by clockwork
  class SendToBus
    def self.trigger_delayed_send
      new.delay.send_unsent
    end

    def send_unsent
      conn = Bunny.new("amqp://guest:guest@kazhua.suse.de", threaded: false, log_level: Logger::DEBUG)
      conn.start
      ch = conn.create_channel
      x = Bunny::Exchange.new(ch, :topic, "pubsub")
      Event::Base.not_sent_to_bus.find_each do |e|
        break unless e.send_to_bus(x)
      end
      conn.close
    end
  end
end
