module ActiveXML
  def self.api
    @@transport_api
  end

  def self.setup_transport_api(schema, host, port, prefix = '')
    @@transport_api = Transport.new(schema, host, port, prefix)
  end

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
          @xml = Xmlhash.parse( exception.message )
        rescue TypeError
          Rails.logger.error "Couldn't parse error xml: #{message[0..120]}"
        end
        @xml ||= {'summary' => message[0..120], 'code' => '500'}
      end

      def api_exception
        parse!
        @xml['exception']
      end

      def details
        parse!
        if @xml.has_key? 'details'
          return @xml['details']
        end
        return nil
      end

      def summary
        parse!
        if @xml.has_key? 'summary'
          return @xml['summary']
        else
          return message
        end
      end

      def code
        parse!
        @xml['code']
      end
    end

    class ConnectionError < Error; end
    class UnauthorizedError < Error; end
    class ForbiddenError < Error; end
    class NotFoundError < Error; end
    class NotImplementedError < Error; end

    # TODO: put lots of stuff into base class

    require 'base64'
    require 'net/https'
    require 'net/http'

    attr_accessor :target_uri
    attr_accessor :details

    def logger
      Rails.logger
    end

    def connect(model, target, opt = {})
      opt.keys.each do |key|
        opt[key] = URI(opt[key])
        replace_server_if_needed( opt[key] )
      end

      uri = URI( target )
      replace_server_if_needed( uri )
      # logger.debug "setting up transport for model #{model}: #{uri} opts: #{opt}"
      raise "overwriting #{model}" if @mapping.has_key? model
      @mapping[model] = {target_uri: uri, opt: opt}
    end

    def replace_server_if_needed( uri )
      unless uri.host
        uri.scheme, uri.host, uri.port = @schema, @host, @port
      end
    end

    def target_for( model )
      # logger.debug "retrieving target_uri for model '#{model.inspect}' #{@mapping.inspect}"
      raise "Model #{model.inspect} is not configured" unless @mapping.has_key? model
      @mapping[model][:target_uri]
    end

    def options_for( model )
      # logger.debug "retrieving option hash for model '#{model.inspect}' #{@mapping.inspect}"
      @mapping[model][:opt]
    end

    def initialize( schema, host, port, prefix = '' )
      @schema = schema
      @host = host
      @port = port
      @prefix = prefix
      @default_servers ||= Hash.new
      @http_header = {"Content-Type" => "text/plain", 'Accept-Encoding' => 'identity'}
      # stores mapping information
      # key: symbolified model name
      # value: hash with keys :target_uri and :opt (arguments to connect method)
      @mapping = Hash.new
    end

    def login( user, password )
      @http_header ||= Hash.new
      @http_header['Authorization'] = 'Basic ' + Base64.encode64( "#{user}:#{password}" )
    end

    # returns object
    def find( model, *args )
      logger.debug "[REST] find( #{model.inspect}, #{args.inspect} )"
      params = Hash.new
      data = nil
      own_mimetype = nil
      symbolified_model = model.name.downcase.split('::').last.to_sym
      uri = target_for( symbolified_model )
      options = options_for( symbolified_model )
      case args[0]
      when Symbol
        # logger.debug "Transport.find: using symbol"
        # raise ArgumentError, "Illegal symbol, must be :all (or String/Hash)" unless args[0] == :all
        uri = options[args[0]]
        if args.length > 1
          #:conditions triggers atm. always a post request, the conditions are
          # transmitted as post-data
          if args[1].has_key? :conditions
            data = args[1][:conditions]
          end
          params = args[1].merge params
        end
      when String
        raise ArgumentError.new "find with string is no longer allowed #{args.inspect}"
      when Hash
        # logger.debug "Transport.find: using hash"
        if args[0].has_key?(:predicate) && args[0].has_key?(:what)
          own_mimetype = "application/x-www-form-urlencoded"
        end
        params = args[0]
      else
        raise "Illegal first parameter, must be Symbol/String/Hash"
      end

      logger.debug "params #{params.inspect}"
      logger.debug "uri is: #{uri}"

      url = substitute_uri( uri, params )
      if own_mimetype
        data = url.query
        url.query = nil
      end
      # use get-method if no conditions defined <- no post-data is set.
      if data.nil?
        # logger.debug"[REST] Transport.find using GET-method"
        objdata = http_do('get', url, timeout: 300)
        raise RuntimeError, "GET to #{url} returned no data" if objdata.empty?
      else
        # use post-method
        logger.debug "[REST] Transport.find using POST-method"
        # logger.debug"[REST] POST-data as xml: #{data.to_s}"
        objdata = http_do('post', url, data: data.to_s, content_type: own_mimetype)
        raise RuntimeError, "POST to #{url} returned no data" if objdata.empty?
      end
      objdata = objdata.force_encoding("UTF-8")
      [objdata, params]
    end

    def create(object, opt = {})
      logger.debug "creating object #{object.class} (#{object.init_options.inspect}) to api:\n #{object.dump_xml}"
      url = substituted_uri_for( object, :create, opt )
      http_do 'post', url, data: object.dump_xml
    end

    def save(object, opt = {})
      logger.debug "saving object #{object.class} (#{object.init_options.inspect}) to api:\n #{object.dump_xml}"
      url = substituted_uri_for( object, nil, opt )
      http_do 'put', url, data: object.dump_xml
    end

    def delete(object, opt = {})
      logger.debug "delete object #{object.class} (#{object.init_options.inspect}) to api:\n #{object.dump_xml}"
      url = substituted_uri_for( object, :delete, opt )
      http_do 'delete', url
    end

    # defines an additional header that is passed to the REST server on every subsequent request
    # e.g.: set_additional_header( "X-Username", "margarethe" )
    def set_additional_header( key, value )
      if value.nil? && @http_header.has_key?(key)
        @http_header[key] = nil
      end

      @http_header[key] = value
    end

    # delete a header field set with set_additional_header
    def delete_additional_header( key )
      if @http_header.has_key? key
        @http_header.delete key
      end
    end

    # TODO: get rid of this very thin wrapper
    def direct_http( url, opt = {} )
      defaults = {method: "GET"}
      opt = defaults.merge opt

      logger.debug "--> direct_http url: #{url.inspect}"

      http_do opt[:method], url, opt
    end

    # replaces the parameter parts in the uri from the config file with the correct values
    def substitute_uri( uri, params )
      # logger.debug "[REST] reducing args: #{params.inspect}"
      params.delete(:conditions)
      # logger.debug "[REST] args is now: #{params.inspect}"

      u = uri.clone
      u.scheme = uri.scheme
      u.path = URI.escape(uri.path.split(/\//).map { |x| x =~ /^:(\w+)/ ? params[$1.to_sym] : x }.join("/"))
      if uri.query
        new_pairs = []
        pairs = u.query.split(/&/).map{|x| x.split(/=/, 2)}
        pairs.each do |pair|
          if pair.length == 2
            if pair[1] =~ /:(\w+)/
              next if !params.has_key?($1.to_sym) || params[$1.to_sym].nil?
              pair[1] = CGI.escape(params[$1.to_sym])
            end
            new_pairs << pair.join("=")
          elsif pair.length == 1
            pair[0] =~ /:(\w+)/
            # new substitution rules:
            # when param is not there, don't put anything in url
            # when param is array, put multiple params in url
            # when param is a hash, put key=value params in url
            # any other case, stringify param and put it in url
            next if !params.has_key?($1.to_sym) || params[$1.to_sym].nil?
            sub_val = params[$1.to_sym]
            if sub_val.kind_of? Array
              sub_val.each do |val|
                new_pairs << $1 + "=" + CGI.escape(val)
              end
            elsif sub_val.kind_of? Hash
              sub_val.each_key do |key|
                new_pairs << CGI.escape(key) + "=" + CGI.escape(sub_val[key])
              end
            else
              new_pairs << $1 + "=" + CGI.escape(sub_val.to_s)
            end
          else
            raise RuntimeError, "illegal url query pair: #{pair.inspect}"
          end
        end
        u.query = new_pairs.join("&")
      end
      u.path.gsub!(/\/+/, '/')
      u
    end

    def substituted_uri_for( object, path_id = nil, opt = {} )
      symbolified_model = object.class.name.downcase.split('::').last.to_sym
      options = options_for(symbolified_model)
      if path_id && options.has_key?(path_id)
        uri = options[path_id]
      else
        uri = target_for( symbolified_model )
      end
      substitute_uri( uri, object.instance_variable_get("@init_options").merge(opt) )
    end

    def http_do( method, url, opt = {} )
      defaults = {timeout: 60}
      opt = defaults.merge opt

      if url.kind_of? String
        url = URI(url)
      end

      # set default host if not set in uri
      url.scheme, url.host = @schema, @host unless url.host
      url.port ||= @port

      method = method.downcase.to_sym
      start = Time.now

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
          @http.use_ssl = true if url.scheme == "https"
          # esp. for the appliance we trust the localhost or we have problems anyway
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE if url.host == "localhost"
          @http.start
        end
        @http.read_timeout = opt[:timeout]

        raise "url.path.nil" if url.path.nil?
        path = @prefix + url.path
        path += "?" + url.query if url.query
        logger.debug "http_do: method: #{method} url: " +
        "http#{"s" if @http.use_ssl?}://#{url.host}:#{url.port}#{path}"

        clength = { "Content-Length" => "0" }
        if opt[:data].respond_to?(:read)
          # TODO: streaming doesn't work - move to rest-client and be done
          opt[:data] = opt[:data].read
        end
        if opt[:data].respond_to?(:length)
          clength["Content-Length"] = opt[:data].length().to_s()
        end
        clength["Content-Type"] = opt[:content_type] unless opt[:content_type].nil?

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
        when :post
          http_response = @http.post path, opt[:data], @http_header.merge(clength)
        when :delete
          http_response = @http.delete path, @http_header
        else
          raise "unknown HTTP method: #{method.inspect}"
        end
      rescue Timeout::Error, Errno::ETIMEDOUT, EOFError
        logger.error "--> caught timeout, closing HTTP"
        keepalive = false
        raise Timeout::Error
      rescue SocketError, Errno::EINTR, Errno::EPIPE, Net::HTTPBadResponse, IOError => err
        keepalive = false
        raise ConnectionError, "Connection failed #{err.class}: #{err.message} for #{url}"
      rescue SystemCallError => err
        keepalive = false
        raise ConnectionError, "Failed to establish connection for #{url}: " + err.message
      ensure
        if details && details.respond_to?('add') && http_response
          runtime = http_response["X-Runtime"]
          payload = http_response["X-Opensuse-Runtimes"]
          payload = JSON.parse(payload) if payload
          payload ||= {}
          if runtime
            payload[:runtime] = Float(runtime) * 1000
          end
          payload[:all] = (Time.now - start) * 1000
          details.add(payload)
          logger.debug "RT #{url} #{payload.inspect}"
        end
        unless keepalive
          @http.finish if @http.started?
          @http = nil
        end
      end

      handle_response( http_response )
    end

    def load_external_url(uri)
      uri = URI.parse(uri)
      http = nil
      content = nil
      proxyuri = ENV['http_proxy']
      proxyuri = CONFIG['http_proxy'] unless CONFIG['http_proxy'].blank?
      noproxy = ENV['no_proxy']
      noproxy = CONFIG['no_proxy'] unless CONFIG['no_proxy'].blank?

      noproxy_applies = false
      if noproxy
        np_split = noproxy.split(",")
        noproxy_applies = np_split.any?{ |np| uri.host.end_with?(np.strip) }
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
        if response.is_a?(Net::HTTPSuccess)
          content = response.body
        end
      rescue SocketError, Errno::EINTR, Errno::EPIPE, EOFError, Net::HTTPBadResponse, IOError, Errno::ENETUNREACH,
        Errno::ETIMEDOUT, Errno::ECONNREFUSED, Timeout::Error => err
        logger.debug "#{err} when fetching #{uri}"
        http = nil
      end
      http.finish if http && http.started?
      content
    end

    # small helper function to avoid having to hardcode the content_type all around
    def http_json(method, uri, data = nil)
      opts = { content_type: "application/json" }
      if data
        opts[:data] = data.to_json
      end
      http_do method, uri, opts
    end

    # needed for streaming data - to avoid the conversion to UTF-8 and similiar to change what "length" is
    def last_body_length
      @last_body_length || 0
    end

    def handle_response( http_response )
      case http_response
      when Net::HTTPSuccess, Net::HTTPRedirection
        body = http_response.read_body
        @last_body_length = body.length
        return body.force_encoding("UTF-8")
      when Net::HTTPNotFound
        raise NotFoundError, http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPUnauthorized
        raise UnauthorizedError, http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPForbidden
        raise ForbiddenError, http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPGatewayTimeOut, Net::HTTPRequestTimeOut
        raise Timeout::Error
      when Net::HTTPBadGateway
        raise Timeout::Error
      end
      message = http_response.read_body
      message = http_response.to_s if message.blank?
      raise Error, message.force_encoding("UTF-8")
    end
  end
end
