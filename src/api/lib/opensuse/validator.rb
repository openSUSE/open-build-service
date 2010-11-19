require 'tempfile'

# method for mapping actions in a controller to schemas
# use in controller definition file
# 
# Example:
#
# class FooController < ActionController::Base
#
#   # data received in a put request in action index will be validated
#   # against schema project.xsd
#   validate_action :index => :project
#
#   def index
#     if @request.put?
#       # request data has already been validated here
#     end
#   end
#
# end
#
module ActionController
  class Base

    class << self
      # Tells validator to validate incoming XML (contained in the request body) agains the
      # specified schema. Takes a hash of <action> => <schema> pairs where both values are symbolified
      # names. The extension for XML schemas is appended to the stringified <schema> value
      #
      # Example:
      #   class FooController < ApplicationController
      #     
      #     validate_action :bar_action => :bar_schema
      #
      #     def bar_action
      #       #
      #     end
      #   end
      def validate_action( opt )
        controller = self.name.match(/^(.*?)Controller/)[1].downcase
        opt.each do |action, schema|
          Suse::Validator.add_schema_mapping( controller, action, schema )
        end
      end
    end

    def validate_incoming_xml
      #only validate PUT requests
      return true unless request.put?
      Suse::Validator.new(params).validate(request.raw_post.to_s)
    end

    def validate_outgoing_xml
      Suse::Validator.new(params).validate(response.body)
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

      def add_schema_mapping( controller, action, schema )
        logger.debug "add validation mapping: #{controller.inspect}, #{action.inspect} => #{schema.inspect}"
        controller = controller.to_s
        action = action.to_s
        schema = schema.to_s

        @schema_map ||= Hash.new
        @schema_map[controller] ||= Hash.new
        @schema_map[controller][action] = schema
      end

      def get_schema( opt )
        unless opt.has_key?(:controller) and opt.has_key?(:action)
          raise "Suse::Validation.get_schema: option hash needs keys :controller and :action"
        end
        c = opt[:controller].to_s
        a = opt[:action].to_s

        logger.debug "checking schema map for controller '#{c}', action '#{a}'"
       
        return nil if @schema_map.nil?
        return nil unless @schema_map.has_key? c and @schema_map[c].has_key? a

        @schema_map[c][a].to_s
      end

      def dump_map
        @schema_map.inspect
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
          raise "Suse::Validation: unable to read schema file '#{schema_path}' or .xsd: file not found"
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
