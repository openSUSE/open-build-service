class UpdateNotificationEvents
  cattr_accessor :semaphore

  def initialize
    self.class.semaphore = semaphore || Mutex.new
  end

  def create_events
    Event::Base.transaction do
      data = type = nil
      @last.elements('notification') do |e|
        type = e['type']
        data = {}
        e.elements('data') do |d|
          data[d['key']] = d['_content']
        end
        event = Event::Factory.new_from_type(type, data)
        event.save!
      end
    end

    BackendInfo.lastnotification_nr = Integer(@last['next'])
  end

  def perform
    if semaphore.locked?
      Rails.logger.debug 'skip lastnotifications, still locked'
      return
    end

    # pick first admin so we can see all projects - as this function is called from delayed job
    User.session ||= User.default_admin

    loop do
      semaphore.synchronize do
        nr = BackendInfo.lastnotification_nr
        # 0 is a bad start
        nr = 1 if nr.zero?

        begin
          @last = Xmlhash.parse(Backend::Api::Server.last_notifications(nr))
        rescue Net::ReadTimeout, EOFError, Backend::Error
          return
        end

        if @last['sync'] == 'lost'
          # we're doomed, but we can't help - it's not supposed to happen
          BackendInfo.lastnotification_nr = Integer(@last['next'])
          return
        end

        create_events
      end

      break if !defined?(@last) || @last['limit_reached'].blank?
    end
  end
end
