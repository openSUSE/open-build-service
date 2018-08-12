module ActiveXML
  def self.backend
    @@transport_backend
  end

  def self.setup_transport_backend(schema, host, port)
    @@transport_backend = Transport.new(schema, host, port)
  end

  class Transport
    attr_accessor :port

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

    # TODO: put lots of stuff into base class

    attr_accessor :target_uri
    attr_accessor :details

    def logger
      Rails.logger
    end

    def initialize(schema, host, port)
      @schema = schema
      @host = host
      @port = port
      @default_servers ||= {}
      @http_header = { 'Content-Type' => 'text/plain', 'Accept-Encoding' => 'identity' }
      # stores mapping information
      # key: symbolized model name
      # value: hash with keys :target_uri and :opt (arguments to connect method)
      @mapping = {}
    end

    # TODO: get rid of this very thin wrapper
    def direct_http(url, opt = {})
      defaults = { method: 'GET' }
      opt = defaults.merge(opt)

      logger.debug "--> direct_http url: #{url}"

      http_do opt[:method], URI.encode(url.to_s, /\+/), opt
    end

    def http_do(method, url, opt = {})
      defaults = { timeout: 60 }
      opt = defaults.merge(opt)

      url = URI(url) if url.is_a?(String)

      # set default host if not set in uri
      unless url.host
        url.scheme = @schema
        url.host = @host
      end
      url.port ||= @port

      method = method.downcase.to_sym

      case method
      when :put, :post, :delete
        @http.finish if @http && @http.started?
        @http = nil
        keepalive = false
      when :get
        # if the http existed before, we shall retry
        keepalive = true
      end
      begin
        unless @http
          @http = Net::HTTP.new(url.host, url.port)
          @http.use_ssl = true if url.scheme == 'https'
          # esp. for the appliance we trust the localhost or we have problems anyway
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE if url.host == 'localhost'
          @http.start
        end
        @http.read_timeout = opt[:timeout]

        raise 'url.path.nil' if url.path.nil?
        path = url.path
        path += '?' + url.query if url.query
        logger.debug "http_do: method: #{method} url: " \
                     "http#{'s' if @http.use_ssl?}://#{url.host}:#{url.port}#{path}"

        clength = { 'Content-Length' => '0' }
        if opt[:data].respond_to?(:read)
          # TODO: streaming doesn't work - move to rest-client and be done
          opt[:data] = opt[:data].read
        end
        if opt[:data].respond_to?(:length)
          clength['Content-Length'] = opt[:data].length.to_s
        end
        clength['Content-Type'] = opt[:content_type] unless opt[:content_type].nil?

        case method
        when :get
          http_response = @http.get path, @http_header
        when :put
          req = Net::HTTP::Put.new(path, @http_header.merge(clength))
          if opt[:data].respond_to?(:read)
            req.body_stream = opt[:data]
          else
            req.body = opt[:data]
          end
          http_response = @http.request(req)
        else
          raise "unknown HTTP method: #{method.inspect}"
        end
      rescue Timeout::Error, Errno::ETIMEDOUT, EOFError
        logger.error '--> caught timeout, closing HTTP'
        keepalive = false
        raise Timeout::Error
      rescue SocketError, Errno::EINTR, Errno::EPIPE, Net::HTTPBadResponse, IOError => err
        keepalive = false
        raise ConnectionError, "Connection failed #{err.class}: #{err.message} for #{url}"
      rescue SystemCallError => err
        keepalive = false
        raise ConnectionError, "Failed to establish connection for #{url}: " + err.message
      ensure
        unless keepalive
          @http.finish if @http.started?
          @http = nil
        end
      end

      handle_response(http_response)
    end

    def load_external_url(uri)
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
        logger.debug "#{err} when fetching #{uri}"
        http = nil
      end
      http.finish if http && http.started?
      content
    end

    def handle_response(http_response)
      case http_response
      when Net::HTTPSuccess, Net::HTTPRedirection
        body = http_response.read_body
        @last_body_length = body.length
        return body.force_encoding('UTF-8')
      when Net::HTTPNotFound
        raise NotFoundError, http_response.read_body.force_encoding('UTF-8')
      when Net::HTTPUnauthorized
        raise UnauthorizedError, http_response.read_body.force_encoding('UTF-8')
      when Net::HTTPForbidden
        raise ForbiddenError, http_response.read_body.force_encoding('UTF-8')
      when Net::HTTPGatewayTimeOut, Net::HTTPRequestTimeOut
        raise Timeout::Error
      when Net::HTTPBadGateway
        raise Timeout::Error
      end
      message = http_response.read_body
      message = http_response.to_s if message.blank?
      raise Error, message.force_encoding('UTF-8')
    end
  end
end
