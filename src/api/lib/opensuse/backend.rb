require 'net/http'
require 'tempfile'
require 'rexml/document'

module Suse
  class Backend

    class ValidationError < Exception; end
    class HTTPError < Exception; end
    class NotFoundError < HTTPError; end
      
    @source_host = SOURCE_HOST
    @source_port = SOURCE_PORT

    @rpm_host = RPM_HOST
    @rpm_port = RPM_PORT

    @schema_location = SCHEMA_LOCATION

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

      # next three methods activate global validation.
      # Suse::Backend.validate_get -> validate all get requests
      # Suse::Backend.validate_put -> validate all put requests
      # Suse::Backend.validate_all -> validate get and put requests
      #
      # by default validation is switched off.

      def validate_get
        self.instance_eval do
          class << self
            alias_method :internal_get, :internal_get_with_validation
          end
        end
      end

      def validate_put
        self.instance_eval do
          class << self
            alias_method :internal_put, :internal_put_with_validation
          end
        end
      end

      def validate_all
        validate_get
        validate_put
      end

      # all get_* and put_* methods take an additional hash used for
      # finetuning validation. global validation settings can be overridden by
      # adding :validate => (true|false) to the parameters.
      #
      # Examples:
      #
      # # validates request regardless of global settings
      # Suse::Backend.get_source( '/some/path', :validate => true )
      #
      # # activates validation on every request
      # Suse::Backend.validate_all
      #
      # # does not validate even though global validation is activated
      # Suse::Backend.put_rpm( '/another/path', @data, :validate => false )
      #
      #
      # the option hash is also passed to the validate method, for setting
      # the schema against which the document is validated. see comment before
      # definition of method validate

      def get( path, opt={} )
        logger.debug "GET: #{path}, #{opt.inspect}"
        get_source path, opt
      end

      def delete( path )
        delete_source path
      end

      def delete_source( path )
        do_delete( source_host, source_port, path )
      end

      def get_source( path, opt={} )
        if opt.has_key? :validate
          if opt[:validate]
            internal_get_with_validation source_host, source_port, path, opt
          else
            internal_get_without_validation source_host, source_port, path
          end
        else
          internal_get source_host, source_port, path, opt
        end
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

      def get_rpm( path, opt={} )
        if opt.has_key? :validate
          if opt[:validate]
            internal_get_with_validation rpm_host, rpm_port, path, opt
          else
            internal_get_without_validation rpm_host, rpm_port, path
          end
        else
          internal_get rpm_host, rpm_port, path, opt
        end
      end

      def put( path, data, opt={} )
        put_source path, data, opt
      end

      def put_source( path, data, opt={} )
        if opt.has_key? :validate
          if opt[:validate]
            internal_put_with_validation source_host, source_port, path, data, opt
          else
            internal_put_without_validation source_host, source_port, path, data
          end
        else
          internal_put source_host, source_port, path, data, opt
        end
      end

      def put_rpm( path, data, opt={} )
        if opt.has_key? :validate
          if opt[:validate]
            internal_put_with_validation rpm_host, rpm_port, path, data, opt
          else
            internal_put_without_validation rpm_host, rpm_port, path, data
          end
        else
          internal_put rpm_host, rpm_port, path, data, opt
        end
      end

      private

      def now
        Time.now.strftime "%Y%m%dT%H%M%S"
      end

      def do_get( host, port, path )
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

      def internal_get_without_validation( host, port, path, opt={} )
        response = Net::HTTP.get_response( host, path, port )
        write_backend_log( "GET", host, port, path, response, response.body )
        handle_response response
      end
      alias_method :internal_get, :internal_get_without_validation

      def internal_put_without_validation( host, port, path, data, opt={} )
        backend_request = Net::HTTP::Put.new( path )
        response = Net::HTTP.start( host, port ) do |http|
          http.request( backend_request, data )
        end
        write_backend_log( "PUT", host, port, path, response, data )
        handle_response response
      end
      alias_method :internal_put, :internal_put_without_validation

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

      def internal_get_with_validation( host, port, path, opt )
        response = internal_get_without_validation( host, port, path )
        validate response.body
        return response
      end

      def internal_put_with_validation( host, port, path, data, opt )
        internal_put_without_validation( host, port, path, validate(data, opt) )
      end

      # validates the passed xml string. the correct schema will be determined
      # either by the passed option :schema (which can be either 
      # '<schema>.xsd' or '<schema>'), or if the option is not set, the root tag of the
      # passed xml string.
      #
      # if validation was successful the string is returned, so that the method can be used
      # like a filter.
      #
      # if validation fails or the root tag cannot be extracted (invalid xml),
      # a Suse::Backend::ValidationError will be raised.
      def validate( xml_string, opt={} )
        if opt[:schema]
          schema = add_schema_ext( opt[:schema] )
        else
          begin
            schema = get_schema_from_xml( xml_string )
          rescue Exception
            raise ValidationError, "invalid xml: #{$!.message}"
          end
        end

        schema = @schema_location + schema
        logger.debug "trying to validate against schema '#{schema}'"

        unless File.exist? schema
          raise ValidationError, "Unable to validate against schema '#{schema}': file not found"
        end

        tmp = Tempfile.new('opensuse_frontend_validator')
        tmp.print xml_string
        tmp_path = tmp.path
        tmp.close

        logger.debug "validation tmpfile: #{tmp_path}"

        out = `/usr/bin/xmllint --noout --schema #{schema} #{tmp_path} 2>&1`
        if $?.exitstatus > 0
          logger.debug "xmllint return value: #{$?.exitstatus}"
          logger.debug "validation.out: #{out}"
          raise ValidationError, "validation failed, output:\n#{out}"
        end
        logger.debug "validation succeeded"

        xml_string
      end

      def add_schema_ext( str )
        str += ".xsd" unless str =~ /\.xsd$/
      end

      def get_schema_from_xml( str )
        REXML::Document.new(str).root.name + ".xsd"
      end
    end
  end
end
