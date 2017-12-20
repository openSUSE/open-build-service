module Backend
  # Class that implements a logger to write output in the backend logs
  class Logger
    @backend_logger = ::Logger.new("#{Rails.root}/log/backend_access.log")
    @backend_time = 0

    def self.reset_runtime
      @backend_time = 0
    end

    def self.runtime
      @backend_time
    end

    def self.info(method, host, port, path, response, start_time)
      time_delta = Time.now - start_time
      now = Time.now.strftime '%Y%m%dT%H%M%S'
      @backend_logger.info "#{now} #{method} #{host}:#{port}#{path} #{response.code} #{time_delta}"
      @backend_time += time_delta
      Rails.logger.debug "request took #{time_delta} #{@backend_time}"

      return unless CONFIG['extended_backend_log']

      data = response.body
      if data.nil?
        @backend_logger.info '(no data)'
      elsif data.class == 'String' && data[0, 1] == '<'
        @backend_logger.info data
      else
        @backend_logger.info "(non-XML data) #{data.class}"
      end
    end
  end
end
