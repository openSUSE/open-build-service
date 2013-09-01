require 'event/factory'

class UpdateNotificationEvents
  def create_events
    @last.elements('notification') do |e|
      type = e['type']
      data = {}
      e.elements('data') do |d|
        data[d['key']] = d['_content']
      end
      event = Event::Factory.new_from_type(type, data)
      event.save!
    end
    BackendInfo.lastnotification_nr = Integer(@last['next'])
  end

  def perform
    # pick first admin so we can see all projects - as this function is called from delayed job
    User.current ||= User.get_default_admin

    nr = BackendInfo.lastnotification_nr
    # 0 is a bad start
    nr = 1 if nr == 0
    @last = Xmlhash.parse(Suse::Backend.get("/lastnotifications?start=#{nr}").body)

    if @last['sync'] == 'lost'
      # we're doomed, but we can't help - it's not supposed to happen
      BackendInfo.lastnotification_nr = Integer(@last['next'])
      return
    end

    Event::Base.transaction do
      create_events
    end

  end
end
