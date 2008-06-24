require 'net/http'

module Suse
  class Backend

    class HTTPError < Exception; end
    class NotFoundError < HTTPError; end
      
    @source_host = SOURCE_HOST
    @source_port = SOURCE_PORT

    @rpm_host = RPM_HOST
    @rpm_port = RPM_PORT

    @@backend_logger = Logger.new( "#{RAILS_ROOT}/log/backend_access.log" )
    
    class << self

      attr_accessor :source_host, :source_port
      attr_accessor :rpm_host, :rpm_port

      def host
        @source_host
      end

      def port
        @source_port
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
        logger.debug "[backend] GET: #{path}"
        backend_request = Net::HTTP::Get.new(path, in_headers)

        response = Net::HTTP.start(host, port) do |http|
          http.request backend_request
        end

        #FIXME: don't call body here, it reads big bodies (files) into memory
        write_backend_log "GET", host, port, path, response, response.body
        handle_response response
      end

      def put(path, data, in_headers={})
        logger.debug "[backend] PUT: #{path}"
        backend_request = Net::HTTP::Put.new(path, in_headers)
        response = Net::HTTP.start(host, port) do |http|
          http.request backend_request, data
        end
        write_backend_log "PUT", host, port, path, response, data
        handle_response response
        #do_put(source_host, source_port, path, data)
      end

      def post(path, data, in_headers={})
        in_headers = {
          'Content-Type' => 'application/octet-stream'
        }.merge in_headers
        logger.debug "[backend] POST: #{path}"
        backend_request = Net::HTTP::Post.new(path, in_headers)
        response = Net::HTTP.start(host, port) do |http|
          http.request backend_request, data
        end
        write_backend_log "POST", host, port, path, response, data
        handle_response response
        #do_post(source_host, source_port, path, data)
      end

      def delete(path, in_headers={})
        logger.debug "[backend] DELETE: #{path}"
        backend_request = Net::HTTP::Delete.new(path, in_headers)
        response = Net::HTTP.start(host, port) do |http|
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
        @@backend_logger.info "#{now} #{method} #{host}:#{port}#{path} #{response.code}"
        begin
          log_xml = EXTENDED_BACKEND_LOG
        rescue
        end

        if log_xml
          if data.nil?
            @@backend_logger.info "(no data)"
          elsif data[0,1] == "<"
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
        else
          raise HTTPError, response
        end
      end

    end
  end
end
