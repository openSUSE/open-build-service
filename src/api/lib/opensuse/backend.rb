require 'net/http'
require 'benchmark'
require 'api_exception'

module Suse
  class Backend

    class IllegalEncodingError < APIException
      setup 'invalid_text_encoding'
    end

    @source_host = CONFIG['source_host']
    @source_port = CONFIG['source_port']

    @@backend_logger = Logger.new( "#{Rails.root}/log/backend_access.log" )
    @@backend_time = 0
    
    def initialize
     Rails.logger.debug "init backend"
    end

    class << self

      attr_accessor :source_host, :source_port

      def host
        @source_host
      end

      def port
        @source_port
      end

      def runtime
        @@backend_time
      end

      def reset_runtime
        @@backend_time = 0
      end

      def logger
        Rails.logger
      end

      def get_log( project, repository, package, arch )
        path = "/build/#{project}/#{repository}/#{arch}/#{package}/_log"
        get path
      end

      def get_log_chunk( project, repository, package, arch, start=0 )
        path = "/build/#{project}/#{repository}/#{arch}/#{package}/_log?nostream=1&start=#{start}"
        get path
      end

      def get_rpmlist( project, repository, package, arch )
        path = "/build/#{project}/#{repository}/#{arch}/#{package}"
        get path
      end

      def get(path, in_headers={})
        start_test_backend
        @start_of_last = Time.now
        logger.debug "[backend] GET: #{path}"
        backend_request = Net::HTTP::Get.new(path, in_headers)

        response = Net::HTTP.start(host, port) do |http|
          http.read_timeout = 1000
          http.request backend_request
        end

        write_backend_log "GET", host, port, path, response
        handle_response response
      end

      def put_or_post(method, path, data, in_headers)
        start_test_backend
        @start_of_last = Time.now
        logger.debug "[backend] #{method}: #{path}"
        if method == "PUT"
          backend_request = Net::HTTP::Put.new(path, in_headers)
        else
          backend_request = Net::HTTP::Post.new(path, in_headers)
        end
        if data.respond_to?('read')
          backend_request.content_length = data.size
          backend_request.body_stream = data
        else
          backend_request.body = data
        end
        response = Net::HTTP.start(host, port) do |http|
          if method == "POST"
            # POST requests can be quite complicate and take some time ..
            http.read_timeout = 100000
          else
            http.read_timeout = 1000
          end
          begin
            http.request backend_request
          rescue Errno::EPIPE, Errno::ECONNRESET, SocketError, Errno::EINTR, EOFError, IOError, Errno::ETIMEDOUT
            raise Timeout::Error
          end
        end
        write_backend_log method, host, port, path, response
        handle_response response
      end

      def put(path, data, in_headers={})
        put_or_post("PUT", path, data, in_headers)
      end
      
      def post(path, data, in_headers={})
        in_headers = {
          'Content-Type' => 'application/octet-stream'
        }.merge in_headers
        put_or_post("POST", path, data, in_headers)
      end

      def delete(path, in_headers={})
        start_test_backend
        @start_of_last = Time.now
        logger.debug "[backend] DELETE: #{path}"
        backend_request = Net::HTTP::Delete.new(path, in_headers)
        response = Net::HTTP.start(host, port) do |http|
          http.read_timeout = 1000
          http.request backend_request
        end
        write_backend_log "DELETE", host, port, path, response
        handle_response response
        #do_delete(source_host, source_port, path)
      end

      alias_method :get_source, :get
      alias_method :put_source, :put
      alias_method :post_source, :post
      alias_method :delete_source, :delete

      def build_query_from_hash(hash, key_list=nil)
        key_list ||= hash.keys
        query = key_list.map do |key|
          if hash.has_key?(key)
            str = hash[key].to_s
            str.toutf8
	    unless str.isutf8
              raise IllegalEncodingError.new("Illegal encoded parameter")
            end

            if hash[key].nil?
              # just a boolean argument ?
              [hash[key]].flatten.map {|x| "#{key}"}.join("&")
            else
              [hash[key]].flatten.map {|x| "#{key}=#{CGI.escape(hash[key].to_s)}"}.join("&")
            end
          end
        end

        if query.empty?
          return ""
        else
          return "?"+query.compact.join('&')
        end
      end

      def send_notification(type, params)
        return if CONFIG['global_write_through'] == false
        params[:who] ||= User.current.login
        params[:sender] ||= User.current.login
        logger.debug "send_notification #{type} #{params}"
        data = []
        params.each do |key, value|
          next if value.nil?
          data << "#{key}=#{CGI.escape(value.to_s)}"
        end

        post("/notify/#{type}?#{data.join('&')}", '')
      end

      private

      def now
        Time.now.strftime "%Y%m%dT%H%M%S"
      end

      def write_backend_log(method, host, port, path, response)
        raise "write backend log without start time" unless @start_of_last
        timedelta = Time.now - @start_of_last
        @start_of_last = nil
        @@backend_logger.info "#{now} #{method} #{host}:#{port}#{path} #{response.code} #{timedelta}"
        @@backend_time += timedelta
        logger.debug "request took #{timedelta} #{@@backend_time}"

        if CONFIG['extended_backend_log']
          data = response.body
          if data.nil?
            @@backend_logger.info "(no data)"
          elsif data.class == 'String' and data[0,1] == "<"
            @@backend_logger.info data
          else
            @@backend_logger.info"(non-XML data) #{data.class}"
          end
        end
      end

      def handle_response( response )
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK
          return response
        when Net::HTTPNotFound
          raise ActiveXML::Transport::NotFoundError, response.read_body.force_encoding("UTF-8")
        else
          message = response.read_body
          message = response.to_s if message.blank?
          raise ActiveXML::Transport::Error, message.force_encoding("UTF-8")
        end
      end

      @@backend = nil

      public

      def test_backend?
        return true if @@backend && @@backend != :dont
      end

      def do_not_start_test_backend 
        @@backend = :dont
      end

      def start_test_backend
	#do_not_start_test_backend
        return unless Rails.env.test?
        return if @@backend
        logger.debug "Starting test backend..."
        @@backend = IO.popen("#{Rails.root}/script/start_test_backend")
        logger.debug "Test backend started with pid: #{@@backend.pid}"
        while true do
          line = @@backend.gets
          raise RuntimeError.new('Backend died') unless line
          break if line =~ /DONE NOW/
          logger.debug line.strip
        end
        CONFIG['global_write_through'] = true
        WebMock.disable_net_connect!(allow: CONFIG['source_host'])
        at_exit do
          logger.debug "kill #{@@backend.pid}"
          Process.kill "INT", @@backend.pid
          @@backend = nil
        end
      end

    end
  end
end
