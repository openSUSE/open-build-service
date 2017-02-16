module Event
  # performed from delayed job triggered by clockwork
  class NotifyBackends
    def self.trigger_delayed_sent
      new.delay.send_not_in_queue
    end

    def send_not_in_queue
      Event::Base.not_in_queue.find_each(&:notify_backend)
    end
  end
end
