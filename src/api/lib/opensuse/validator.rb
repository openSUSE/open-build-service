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
      Suse::Validator.new(params).validate(request.raw_post)
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

      unless File.exist? schema_path
        raise Suse::ValidationError, "unable to read schema file '#{schema_path}': file not found"
      end
      
      logger.debug "schema_path: #{schema_path}"
      @schema_path = schema_path
    end

    def validate( document )
      case document
      when String
        doc_str = document
      else
        raise ValidationError, "illegal document type '#{document.class.name}'"
      end
      
      if @schema_path.nil?
        logger.debug "schema path not set, skipping validation"
        return doc_str
      end
      
      logger.debug "trying to validate against schema '#@schema_path'"
      
      tmp = Tempfile.new('opensuse_frontend_validator')
      tmp.print doc_str
      tmp_path = tmp.path
      tmp.close

      logger.debug "validation tmpfile: #{tmp_path}"

      out = `/usr/bin/xmllint --noout --schema #@schema_path #{tmp_path} 2>&1`
      if $?.exitstatus > 0
        logger.debug "xmllint return value: #{$?.exitstatus}"
        logger.debug "XML: #{doc_str}"
        raise ValidationError, "validation failed, output:\n#{out}"
      end
      logger.debug "validation succeeded"

      doc_str

    end
  end
end
