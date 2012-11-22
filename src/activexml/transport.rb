module ActiveXML
  def self.transport
    @@transport
  end

  def self.setup_transport(schema, host, port)
    @@transport = Transport.new(schema, host, port)
  end

  class Transport

    class Error < StandardError
      
      def parse!
        return @xml if @xml

        #Rails.logger.debug "extract #{exception.class} #{exception.message}"
        begin
          @xml = Xmlhash.parse( exception.message )
        rescue TypeError
          Rails.logger.error "Couldn't parse error xml: #{self.message[0..120]}"
          @xml = {'summary' => self.message[0..120], 'code' => '500'}
          return
        end
      end

      def api_exception
        parse!
        return @xml['exception']
      end

      def summary
        parse!
        if @xml.has_key? 'summary'
	  return @xml['summary']
        else
          return self.message
        end
      end

      def code
        parse!
        return @xml['code']
      end
    end

    class ConnectionError < Error; end
    class UnauthorizedError < Error; end
    class ForbiddenError < Error; end
    class NotFoundError < Error; end
    class NotImplementedError < Error; end

    #TODO: put lots of stuff into base class

    require 'base64'
    require 'net/https'
    require 'net/http'

    attr_accessor :target_uri
    attr_accessor :details

    def logger
      Rails.logger
    end

    def connect( model, target, opt={} )
      opt.each do |key,value|
        opt[key] = URI(opt[key])
        replace_server_if_needed( opt[key] )
      end

      uri = URI( target )
      replace_server_if_needed( uri )
      #logger.debug "setting up transport for model #{model}: #{uri} opts: #{opt}"
      @mapping[model] = {:target_uri => uri, :opt => opt}
    end

    def replace_server_if_needed( uri )
      unless uri.host
        uri.scheme, uri.host, uri.port = @schema, @host, @port
      end
    end

    def target_for( model )
      #logger.debug "retrieving target_uri for model '#{model.inspect}'"
      raise "Model #{model.inspect} is not configured" if not @mapping.has_key? model
      @mapping[model][:target_uri]
    end

    def options_for( model )
      #logger.debug "retrieving option hash for model '#{model.inspect}'"
      @mapping[model][:opt]
    end

    def initialize( schema, host, port )
      @schema = schema
      @host = host
      @port = port
      @default_servers ||= Hash.new
      @http_header = {"Content-Type" => "text/plain"}
      # stores mapping information
      # key: symbolified model name
      # value: hash with keys :target_uri and :opt (arguments to connect method)
      @mapping = Hash.new
    end

    def target_uri=(uri)
      uri.scheme = "http"
      @target_uri = uri
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
      symbolified_model = model.name.downcase.to_sym
      uri = target_for( symbolified_model )
      options = options_for( symbolified_model )
      case args[0]
      when Symbol
        #logger.debug "Transport.find: using symbol"
        #raise ArgumentError, "Illegal symbol, must be :all (or String/Hash)" unless args[0] == :all
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
        #logger.debug "Transport.find: using hash"
        if args[0].has_key? :predicate and args[0].has_key? :what
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
      #use get-method if no conditions defined <- no post-data is set.
      if data.nil?
        #logger.debug"[REST] Transport.find using GET-method"
        objdata = http_do( 'get', url, :timeout => 300 )
        raise RuntimeError.new("GET to %s returned no data" % url) if objdata.empty?
      else
        #use post-method
        logger.debug"[REST] Transport.find using POST-method"
        #logger.debug"[REST] POST-data as xml: #{data.to_s}"
        objdata = http_do( 'post', url, :data => data.to_s, :content_type => own_mimetype)
        raise RuntimeError.new("POST to %s returned no data" % url) if objdata.empty?
      end
      objdata = objdata.force_encoding("UTF-8")
      return [objdata, params]
    end

    def create(object, opt={})
      logger.debug "creating object #{object.class} (#{object.init_options.inspect}) to api:\n #{object.dump_xml}"
      url = substituted_uri_for( object, :create, opt )
      http_do 'post', url, :data => object.dump_xml
    end

    def save(object, opt={})
      logger.debug "saving object #{object.class} (#{object.init_options.inspect}) to api:\n #{object.dump_xml}"
      url = substituted_uri_for( object )
      http_do 'put', url, :data => object.dump_xml
    end

    def delete(object, opt={})
      logger.debug "delete object #{object.class} (#{object.init_options.inspect}) to api:\n #{object.dump_xml}"
      url = substituted_uri_for( object, :delete, opt )
      http_do 'delete', url
    end

    # defines an additional header that is passed to the REST server on every subsequent request
    # e.g.: set_additional_header( "X-Username", "margarethe" )
    def set_additional_header( key, value )
      if value.nil? and @http_header.has_key? key
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

    def direct_http( url, opt={} )
      defaults = {:method => "GET"}
      opt = defaults.merge opt

      #set default host if not set in uri
      if not url.host
        url.scheme, url.host, url.port = @schema, @host, @port
      end

      logger.debug "--> direct_http url: #{url.inspect}"

      http_do opt[:method], url, opt
    end

    #replaces the parameter parts in the uri from the config file with the correct values
    def substitute_uri( uri, params )

      #logger.debug "[REST] reducing args: #{params.inspect}"
      params.delete(:conditions)
      #logger.debug "[REST] args is now: #{params.inspect}"

      u = uri.clone
      u.scheme = uri.scheme
      u.path = URI.escape(uri.path.split(/\//).map { |x| x =~ /^:(\w+)/ ? params[$1.to_sym] : x }.join("/"))
      if uri.query
        new_pairs = []
        pairs = u.query.split(/&/).map{|x| x.split(/=/, 2)}
        pairs.each do |pair|
          if pair.length == 2
            if pair[1] =~ /:(\w+)/
              next if not params.has_key? $1.to_sym or params[$1.to_sym].nil?
              pair[1] = CGI.escape(params[$1.to_sym])
            end
            new_pairs << pair.join("=")
          elsif pair.length == 1
            pair[0] =~ /:(\w+)/
            #new substitution rules:
            #when param is not there, don't put anything in url
            #when param is array, put multiple params in url
            #when param is a hash, put key=value params in url
            #any other case, stringify param and put it in url
            next if not params.has_key? $1.to_sym or params[$1.to_sym].nil?
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
      return u
    end

    def substituted_uri_for( object, path_id=nil, opt={} )
      symbolified_model = object.class.name.downcase.to_sym
      options = options_for(symbolified_model)
      if path_id and options.has_key? path_id
        uri = options[path_id]
      else
        uri = target_for( symbolified_model )
      end
      substitute_uri( uri, object.instance_variable_get("@init_options").merge(opt) )
    end

    private

    def http_do( method, url, opt={} )
      defaults = {:timeout => 60}
      opt = defaults.merge opt
      max_retries = 1

      start = Time.now

      case method
      when /put/i, /post/i, /delete/i
        @http.finish if @http
        @http = nil
      when /get/i
        # if the http is existed before, we shall retry
        max_retries = 2 if @http
      end
      retries = 0
      begin
        retries += 1
        keepalive = true
        if not @http
          @http = Net::HTTP.new(url.host, url.port)
          @http.use_ssl = true if url.scheme == "https"
          @http.start
        end
        @http.read_timeout = opt[:timeout]

        path = url.path
        path += "?" + url.query if url.query
        logger.debug "http_do ##{retries}: method: #{method} url: " +
        "http#{"s" if @http.use_ssl?}://#{url.host}:#{url.port}#{path}"

        clength = { "Content-Length" => "0" }
        clength["Content-Length"] = opt[:data].length().to_s() unless opt[:data].nil?
        clength["Content-Type"] = opt[:content_type] unless opt[:content_type].nil?

        case method
        when /get/i
          http_response = @http.get path, @http_header
        when /put/i
          http_response = @http.put path, opt[:data], @http_header.merge(clength)
        when /post/i
          http_response = @http.post path, opt[:data], @http_header.merge(clength)
        when /delete/i
          http_response = @http.delete path, @http_header
        else
          raise "unknown HTTP method: #{method.inspect}"
        end
      rescue Timeout::Error => err
        logger.error "--> caught timeout, closing HTTP"
        @http.finish
        @http = nil
        raise err
      rescue SocketError, Errno::EINTR, Errno::EPIPE, EOFError, Net::HTTPBadResponse, IOError => err
        @http.finish
        @http = nil
        if retries < max_retries
          logger.error "--> caught #{err.class}: #{err.message}, retrying with new HTTP connection"
          retry
        end
        raise Error, "Connection failed #{err.class}: #{err.message} for #{url}"
      rescue SystemCallError => err
        begin
          @http.finish
        rescue => e
          logger.error "Couldn't finish http connection: #{e.message}"
        end
        @http = nil
        raise ConnectionError, "Failed to establish connection for #{url}: " + err.message
      ensure
        if self.details && self.details.respond_to?('add') && http_response
          runtime = http_response["X-Runtime"]
          payload = http_response["X-Opensuse-Runtimes"]
          payload = JSON.parse(payload) if payload
          payload ||= {}
          if runtime
            payload[:runtime] = Float(runtime) * 1000
          end
          payload[:all] = (Time.now - start) * 1000
          self.details.add(payload)
          logger.debug "RT #{url} #{payload.inspect}"
        end
      end

      unless keepalive
        @http.finish
        @http = nil
      end

      return handle_response( http_response )
    end

    def handle_response( http_response )
      case http_response
      when Net::HTTPSuccess, Net::HTTPRedirection
        return http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPNotFound
        raise NotFoundError, http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPUnauthorized
        raise UnauthorizedError, http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPForbidden
        raise ForbiddenError, http_response.read_body.force_encoding("UTF-8")
      when Net::HTTPGatewayTimeOut
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
