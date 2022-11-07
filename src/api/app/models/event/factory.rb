module Event
  # generate an Event class
  class Factory
    def self.new_from_type(type, params)
      # as long as there is no overlap, all these Srcsrv prefixes only look silly
      type.gsub!(/^SRCSRV_/, '')
      begin
        "::Event::#{type.downcase.camelcase}".constantize.new(params)
      rescue NameError => e
        bt = e.backtrace.join("\n")
        Rails.logger.debug { "NameError #{e.inspect} #{bt}" }
        nil
      end
    end
  end
end
