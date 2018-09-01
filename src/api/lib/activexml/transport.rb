module ActiveXML
  class Transport
    class Error < StandardError
      def parse!
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
        parse!
        return @xml['details'] if @xml.key?('details')
        return
      end

      def summary
        parse!
        return @xml['summary'] if @xml.key?('summary')
        return message
      end
    end

    class ConnectionError < Error; end
    class UnauthorizedError < Error; end
    class ForbiddenError < Error; end
    class NotFoundError < Error; end
    class NotImplementedError < Error; end
  end
end
