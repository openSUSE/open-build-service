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

    def self.load_external_url(uri)
      uri = URI.parse(uri)
      http = nil
      content = nil
      proxyuri = ENV['http_proxy']
      proxyuri = CONFIG['http_proxy'] if CONFIG['http_proxy'].present?
      noproxy = ENV['no_proxy']
      noproxy = CONFIG['no_proxy'] if CONFIG['no_proxy'].present?

      noproxy_applies = false
      if noproxy
        np_split = noproxy.split(',')
        noproxy_applies = np_split.any? { |np| uri.host.end_with?(np.strip) }
      end

      if proxyuri && noproxy_applies == false
        proxy = URI.parse(proxyuri)
        proxy_user, proxy_pass = proxy.userinfo.split(/:/) if proxy.userinfo
        http = Net::HTTP::Proxy(proxy.host, proxy.port, proxy_user, proxy_pass).new(uri.host, uri.port)
      else
        http = Net::HTTP.new(uri.host, uri.port)
      end
      http.use_ssl = (uri.scheme == 'https')
      begin
        http.start
        response = http.get uri.request_uri
        content = response.body if response.is_a?(Net::HTTPSuccess)
      rescue SocketError, Errno::EINTR, Errno::EPIPE, EOFError, Net::HTTPBadResponse, IOError, Errno::ENETUNREACH,
             Errno::ETIMEDOUT, Errno::ECONNREFUSED, Timeout::Error => err
        Rails.logger.debug "#{err} when fetching #{uri}"
        http = nil
      end
      http.finish if http && http.started?
      content
    end
  end
end
