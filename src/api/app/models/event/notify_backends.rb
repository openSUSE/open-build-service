module Event

# performed from delayed job triggered by clockwork
 class NotifyBackends
  
  def self.trigger_delayed_sent
    self.new.delay.send_not_in_queue
  end
  
  def send_not_in_queue
    Event::Base.not_in_queue.each do |e|
      if !e.notify_backend
        # if something went wrong, we better stop the queueing here
        return
      end
    end
  end
 end
end
