require 'event'

class UpdateNotificationEvents
  cattr_accessor :semaphore

  def initialize
    self.class.semaphore = semaphore || Mutex.new
  end

  def create_events
    retries = 10
    data = type = nil
    begin
      Event::Base.transaction do
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
    rescue ActiveRecord::StatementInvalid => e
      retries = retries - 1
      retry if retries > 0
      HoptoadNotifier.notify(e, {failed_job: "RETRYED 10 times: #{type.inspect}: #{data}"})
      return
    rescue => e
      if Rails.env.test?
        # make debug output useful in test suite, not just showing backtrace to HoptoaddNotifier
        Rails.logger.error "ERROR: #{e.inspect}: #{e.backtrace}"
        puts e.inspect, e.backtrace
      end
      HoptoadNotifier.notify(e, {failed_job: type.inspect})
      return
    end

    BackendInfo.lastnotification_nr = Integer(@last['next'])
  end

  def perform
    if semaphore.locked?
      Rails.logger.debug "skip lastnotifications, still locked"
      return
    end

    # pick first admin so we can see all projects - as this function is called from delayed job
    User.current ||= User.get_default_admin

    limit_reached = false
    begin
      semaphore.synchronize do
        nr = BackendInfo.lastnotification_nr
        # 0 is a bad start
        nr = 1 if nr.zero?

        begin
          @last = Xmlhash.parse(Suse::Backend.get("/lastnotifications?start=#{nr}&block=1").body)
        rescue Net::ReadTimeout, EOFError, ActiveXML::Transport::Error
          return
        end

        if @last['sync'] == 'lost'
          # we're doomed, but we can't help - it's not supposed to happen
          BackendInfo.lastnotification_nr = Integer(@last['next'])
          return
        end
        limit_reached = @last['limit_reached'].present?

        create_events
      end
    end while limit_reached
  end
end
