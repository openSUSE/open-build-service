class EventNotificationHermes
  def initialize(event)
    @event = event
  end

  def send
    return unless CONFIG['hermes_server']

    args = @event.payload
    type = @event.class.raw_type || "UNKNOWN"

    # prepend something BS specific
    hermesuri = CONFIG['hermes_server'] + "/index.cgi?rm=notify&_type=OBS_#{type}&#{args.to_query}"

    Rails.logger.debug "Notifying hermes at #{hermesuri}"
    Net::HTTP.get(URI(hermesuri))
  end

end