class EventNotificationHermes
  def initialize(event)
    @event = event
  end

  def send
    return true unless CONFIG['hermes_server']

    args = @event.payload
    type = @event.class.raw_type || "UNKNOWN"
    # TODO: come from configuration
    prefix = "OBS"

    # prepend something BS specific
    hermesuri = CONFIG['hermes_server'] + "/index.cgi?rm=notify&_type=#{prefix}_#{type}&#{args.to_query}"

    Rails.logger.debug "Notifying hermes at #{hermesuri}"
    Net::HTTP.get(URI(hermesuri))
    true
  end

end