require 'tempfile'

# This module encapsulates XML schema validation for individual controller actions.
# It allows to verify incoming and outgoing XML data and to set different schemas based
# on the request type (GET, PUT, POST, etc.) and direction (in, out). Supported schema
# types are Schematron, RelaxNG and XML Schema (xsd).
module ActionController
  class Base

    class << self
      # Method for mapping actions in a controller to (XML) schemas based on request
      # method (GET, PUT, POST, etc.). Example:
      #
      # class UserController < ActionController::Base
      #   # Validation on request data is performed based on the request type and the
      #   # provided schema name. Validation for a GET request only checks the XML response,
      #   # whereas a POST request may want to check the (user-supplied) request as well as the
      #   # own response to the request.
      #
      #   validate_action :index => {:method => :get, :response => :users}
      #   validate_action :edit =>  {:method => :put, :request => :user, :response => :status}
      #
      #   def index
      #     # return all users ...
      #   end
      #   
      #   def edit
      #     if @request.put?
      #       # request data has already been validated here
      #     end
      #   end
      # end
      def validate_action( opt )
        controller = self.name.match(/^(.*?)Controller/)[1].downcase
        opt.each do |action, action_opt|
          Suse::Validator.add_schema_mapping(controller, action, action_opt)
        end
      end
    end

    # This method should be called in the ApplicationController of your Rails app.
    def validate_xml_request
      opt = params()
      opt[:method] = request.method.to_s
      opt[:type] = "request"
      Suse::Validator.new(opt).validate(request.raw_post.to_s)
    end

    # This method should be called in the ApplicationController of your Rails app.
    def validate_xml_response
      opt = params()
      opt[:method] = request.method.to_s
      opt[:type] = "response"
      Suse::Validator.new(opt).validate(response.body)
    end

  end
end

module Suse
  class ValidationError < Exception; end
  
  class Validator
    @schema_location = SCHEMA_LOCATION

    class << self
      attr_reader :schema_location

      def logger
        RAILS_DEFAULT_LOGGER
      end

      # Adds an action to schema mapping. Internally, the mapping is done like this:
      #
      # [controller][action-method-response] = schema
      # [controller][action-method-request] = schema
      #
      # For the above example, the resulting mapping looks like:
      #
      # [user][index-get-reponse] = users
      # [user][edit-put-request] = user
      # [user][edit-put-response] = status
      def add_schema_mapping( controller, action, opt )
        unless opt.has_key?(:method) and (opt.has_key?(:request) or opt.has_key?(:response))
          raise "missing (or wrong) parameters, #{opt.inspect}"
        end
        logger.debug "add validation mapping: #{controller.inspect}, #{action.inspect} => #{opt.inspect}"

        controller = controller.to_s
        @schema_map ||= Hash.new
        @schema_map[controller] ||= Hash.new
        key = action.to_s + "-" + opt[:method].to_s
        if opt[:request]   # have a request validation schema?
          @schema_map[controller][key + "-request"] = opt[:request].to_s
        end
        if opt[:response]  # have a reponse validate schema?
          @schema_map[controller][key + "-response"] = opt[:response].to_s
        end
      end

      # Retrieves the schema filename from the action to schema mapping.
      def get_schema( opt )
        unless opt.has_key?(:controller) and opt.has_key?(:action) and opt.has_key?(:method) and opt.has_key?(:type)
          raise "option hash needs keys :controller and :action"
        end
        c = opt[:controller].to_s
        key = opt[:action].to_s + "-" + opt[:method].to_s + "-" + opt[:type].to_s

        logger.debug "checking schema map for controller '#{c}', key: '#{key}'"
       
        return nil if @schema_map.nil?
        return nil unless @schema_map.has_key? c and @schema_map[c].has_key? key
        return @schema_map[c][key].to_s
      end
    end

    def logger
      RAILS_DEFAULT_LOGGER
    end

    def initialize( opt )
      case opt
      when String, Symbol
        schema_file = opt.to_s
      when Hash
        schema_file = self.class.get_schema(opt)
      else
        raise "illegal initialization option to Suse::Validator; need: Hash/Symbol/String, seen: #{opt.class.name}"
      end

      logger.debug "schema_file: #{schema_file}"
      return if schema_file.nil?

      schema_file += ".xsd" unless schema_file =~ /\.xsd$/
      schema_path = self.class.schema_location + schema_file
      @xmllint_param = "--schema"

      unless File.exist? schema_path
        # no .xsd file found, try with an .rng
        schema_file = schema_file.split(/\.xsd$/)[0] + ".rng" unless schema_file =~ /\.rng\.xsd$/
        schema_path = self.class.schema_location + schema_file
        @xmllint_param = "--relaxng"
        unless File.exist? schema_path
          # does not exist either ... error ...
          raise "Unable to read schema file '#{schema_path}' or .xsd: file not found"
        end
      end

      logger.debug "schema_path: #{schema_path}"
      @schema_path = schema_path
    end

    def validate( content )
      if @schema_path.nil?
        logger.debug "schema path not set, skipping validation"
        return true
      end
      logger.debug "trying to validate against schema '#{@schema_path}'"

      tmp = Tempfile.new('opensuse_frontend_validator')
      tmp.print content
      tmp_path = tmp.path
      tmp.close
      logger.debug "validation tmpfile: #{tmp_path}"

      cmd = "/usr/bin/xmllint --noout #{@xmllint_param} #{@schema_path} #{tmp_path}"
      out = `#{cmd} 2>&1`
      exitstatus = $?.exitstatus 
      logger.debug "#{cmd} returned #{exitstatus}"
      if exitstatus != 0
        logger.debug "xmllint return value: #{$?.exitstatus}"
        logger.debug "XML: #{content} #{out}"
        raise ValidationError, "validation failed, output:\n#{out}"
      end
      logger.debug "validation succeeded"

      return true
    end

  end
end
