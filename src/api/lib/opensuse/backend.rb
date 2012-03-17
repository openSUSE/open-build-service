require 'net/http'
require 'benchmark'

module Suse
  class Backend

    class HTTPError < Exception
      def initialize(resp)
        @resp = resp
      end

      def to_s
        @resp.body
      end
    end

    class NotFoundError < HTTPError
    end
      
    @source_host = SOURCE_HOST
    @source_port = SOURCE_PORT

    @@backend_logger = Logger.new( "#{RAILS_ROOT}/log/backend_access.log" )
    @backend_time = 0
    
    class << self

      attr_accessor :source_host, :source_port

      def host
        @source_host
      end

      def port
        @source_port
      end

      def runtime
        @backend_time
      end

      def reset_runtime
        @backend_time = 0
      end

      def logger
        RAILS_DEFAULT_LOGGER
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

        #FIXME: don't call body here, it reads big bodies (files) into memory
        write_backend_log "GET", host, port, path, response, response.body
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
          rescue Errno::EPIPE, Errno::ECONNRESET
            raise Timeout::Error
          end
        end
        write_backend_log method, host, port, path, response, data
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
        write_backend_log"DELETE", host, port, path, response, response.body
        handle_response response
        #do_delete(source_host, source_port, path)
      end

      alias_method :get_source, :get
      alias_method :put_source, :put
      alias_method :post_source, :post
      alias_method :delete_source, :delete

      private

      def now
        Time.now.strftime "%Y%m%dT%H%M%S"
      end

      def write_backend_log(method, host, port, path, response, data)
        raise "write backend log without start time" unless @start_of_last
        timedelta = Time.now - @start_of_last
        @start_of_last = nil
        @@backend_logger.info "#{now} #{method} #{host}:#{port}#{path} #{response.code} #{timedelta}"
        @backend_time += timedelta
        logger.debug "request took #{timedelta}"

        if (defined? EXTENDED_BACKEND_LOG) and EXTENDED_BACKEND_LOG
          if data.nil?
            @@backend_logger.info "(no data)"
          elsif data.class == 'String' and data[0,1] == "<"
            @@backend_logger.info data
          else
            @@backend_logger.info"(non-XML data)"
          end
        end
      end

      def handle_response( response )
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection
          return response
        when Net::HTTPNotFound
          raise NotFoundError.new(response)
        else
          raise HTTPError.new(response)
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
    ActiveXML::Config.global_write_through = true
    at_exit do
      logger.debug "kill #{@@backend.pid}"
      Process.kill "INT", @@backend.pid
      @@backend = nil
    end
  end

    end
  end
end
