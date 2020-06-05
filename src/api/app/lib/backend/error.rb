module Backend
  class Error < StandardError
    def xml
      return @xml if @xml

      # Rails.logger.debug "extract #{exception.class} #{exception.message}"
      begin
        @xml = Xmlhash.parse(exception.message)
      rescue TypeError
        Rails.logger.error "Couldn't parse error xml: #{message[0..120]}"
      end
      @xml ||= { 'summary' => message[0..120], 'code' => '500' }
    end

    def details
      xml['details']
    end

    def summary
      xml['summary'] || message
    end
  end

  class NotFoundError < Error; end
end
