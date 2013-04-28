require 'tempfile'
require 'stringio'

# This module encapsulates XML schema validation for individual controller actions.
# It allows to verify incoming and outgoing XML data and to set different schemas based
# on the request type (GET, PUT, POST, etc.) and direction (in, out). Supported schema
# types are RelaxNG and XML Schema (xsd).
module ActionController
  class API

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
        opt.each do |action, action_opt|
          Suse::Validator.add_schema_mapping(self.controller_path, action, action_opt)
        end
      end
    end

    # This method should be called in the ApplicationController of your Rails app.
    def validate_xml_request
      opt = params()
      opt[:method] = request.method.to_s
      opt[:type] = "request"
      logger.debug "Validate XML request: #{request}"
      Suse::Validator.validate(opt, request.raw_post.to_s)
    end

    # This method should be called in the ApplicationController of your Rails app.
    def validate_xml_response
      return if @skip_validation 
      if request.format != "json" && response.status.to_s[0..2] == "200" && response.headers['Content-Type'] !~ /.*\/json/i && response.headers["Content-Disposition"] != "attachment"
        opt = params()
        opt[:method] = request.method.to_s
        opt[:type] = "response"
        ms = Benchmark.ms do
         if response.body.respond_to? :call
          sio = StringIO.new()
          response.body.call(nil, sio) # send_file can return a block that takes |response, output|
          str = sio.string
         else
          str = response.body
         end
         Suse::Validator.validate(opt, str)
	end
	logger.debug "Validate XML response: #{response} took #{Integer(ms + 0.5)}ms"
      end
    end

  end
end

module Suse
  class ValidationError < APIException
    setup 'validation_failed'
  end
  
  class Validator
    @schema_location = CONFIG['schema_location']

    class << self
      attr_reader :schema_location

      def logger
        Rails.logger
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
        #logger.debug "add validation mapping: #{controller.inspect}, #{action.inspect} => #{opt.inspect}"

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
        key = opt[:action].to_s + "-" + opt[:method].to_s.downcase + "-" + opt[:type].to_s

        #logger.debug "checking schema map for controller '#{c}', key: '#{key}'"
        return nil if @schema_map.nil?
        return nil unless @schema_map.has_key? c and @schema_map[c].has_key? key
        return @schema_map[c][key].to_s
      end

      # validate ('schema.xsd', '<foo>bar</foo>")
      def validate( opt, content )
        case opt
        when String, Symbol
          schema_file = opt.to_s
        when Hash, HashWithIndifferentAccess
          schema_file = get_schema(opt).to_s
        else
          raise "illegal option; need Hash/Symbol/String, seen: #{opt.class.name}"
        end

        schema_base_filename = schema_location + "/" + schema_file
        schema = nil
        if File.exists? schema_base_filename + ".rng"
          schema = Nokogiri::XML::RelaxNG(File.open(schema_base_filename + ".rng"))
        elsif File.exists? schema_base_filename + ".xsd"
          schema = Nokogiri::XML::Schema(File.open(schema_base_filename + ".xsd"))
        else
          logger.debug "no schema found, skipping validation for #{opt.inspect}"
          return true
        end

        if content.nil?
          raise "illegal option; need content for #{schema_base_filename}"
        end
        if content.empty?
          logger.debug "no content, skipping validation for #{schema_file}"
          raise ValidationError, "Document is empty, not allowed for #{schema_base_filename}"
        end

        begin
          doc = Nokogiri::XML(content, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
          schema.validate(doc).each do |error|
            logger.error "validation error: #{error}"
            logger.debug "Schema #{schema_file} for: #{content}"
            # Only raise an exception for user-input validation!
            raise ValidationError, "#{schema_file} validation error: #{error}"
          end
        rescue Nokogiri::XML::SyntaxError => error
          raise ValidationError, "#{schema_file} validation error: #{error}"
        end
        return true
      end
    end

  end
end
