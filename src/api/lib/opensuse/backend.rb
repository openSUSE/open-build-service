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

      def host= h
        logger.warn "Suse::Backend: warning: using Suse::Backend.host=() is obsolete, use Suse::Backend.source_host=() !"
        @source_host = h
      end

      def port= p
        logger.warn "Suse::Backend: warning: using Suse::Backend.port=() is obsolete, use Suse::Backend.source_port=() !"
        @source_port = p
      end

      def logger
        RAILS_DEFAULT_LOGGER
      end

      def get( path )
        logger.debug "GET: #{path}"
        get_source path
      end

      def delete( path )
        delete_source path
      end

      def delete_source( path )
        do_delete( source_host, source_port, path )
      end

      def delete_status( project, repository, package, arch )
        path = "/rpm/#{project}/#{repository}/#{arch}/#{package}/status"
        do_delete( rpm_host, rpm_port, path )
      end

      def get_source( path )
        do_get( source_host, source_port, path )
      end

      def get_package_result( project, repository, package )
        path = "/status/#{project}/#{repository}/#{package}"
        do_get( source_host, source_port, path )
      end

      def get_project_result( project )
        path = "/status/#{project}/:all/:all"
        do_get( source_host, source_port, path )
      end

      def get_log( project, repository, package, arch )
        path = "/rpm/#{project}/#{repository}/#{arch}/#{package}/logfile"
        do_get( rpm_host, rpm_port, path )
      end

      def get_log_chunk( project, repository, package, arch, start=0 )
        path = "/rpm/#{project}/#{repository}/#{arch}/#{package}/logfile?nostream=1&start=#{start}"
        do_get( rpm_host, rpm_port, path )
      end


      def get_rpmlist( project, repository, package, arch )
        path = "/rpm/#{project}/#{repository}/#{arch}/#{package}"
        do_get( rpm_host, rpm_port, path )
      end

      def get_rpm( path )
        do_get( rpm_host, rpm_port, path )
      end

      def put( path, data )
        put_source( path, data )
      end

      def put_source( path, data )
        do_put( source_host, source_port, path, data )
      end

      def put_rpm( path, data )
        do_put( rpm_host, rpm_port, path, data )
      end

      private

      def now
        Time.now.strftime "%Y%m%dT%H%M%S"
      end

      def do_get( host, port, path )
        logger.debug "XXX Path: #{path}"
        response = Net::HTTP.get_response( host, path, port )
        write_backend_log( "GET", host, port, path, response, response.body )
        handle_response response
      end

      def do_delete( host, port, path )
        backend_request = Net::HTTP::Delete.new( path )
        response = Net::HTTP.start( host, port ) do |http|
          http.request( backend_request )
        end
        write_backend_log( "DELETE", host, port, path, response, response.body )
        handle_response response
      end

      def do_put( host, port, path, data )
        backend_request = Net::HTTP::Put.new( path )
        response = Net::HTTP.start( host, port ) do |http|
          http.request( backend_request, data )
        end
        write_backend_log( "PUT", host, port, path, response, data )
        handle_response response
      end

      def write_backend_log method, host, port, path, response, data
        @@backend_logger.info( now + " #{method} #{host}:#{port}#{path} #{response.code}" )
        begin
          log_xml = EXTENDED_BACKEND_LOG
        rescue
        end
        if ( log_xml )
          if ( data[0,1] == "<" )
            @@backend_logger.info( data )
          else
            @@backend_logger.info( "(non-XML data)" )
          end
        end
      end

      def handle_response( response )
        #logger.debug "server returned #{response.class}"

        case response
        when Net::HTTPSuccess, Net::HTTPRedirection
          return response
          #when Net::HTTPUnauthorized
          #raise UnauthorizedError, error_doc( response.read_body )
          #when Net::HTTPForbidden
          #raise ForbiddenError, error_doc( response.read_body )
          #when Net::HTTPClientError, Net::HTTPServerError
          #raise HTTPError, error_doc( response.read_body )
        when Net::HTTPNotFound
          raise NotFoundError, response
        end

        raise HTTPError, response
      end

    end
  end
end
