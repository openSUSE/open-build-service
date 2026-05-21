require 'tempfile'
require 'stringio'

# This module encapsulates XML schema validation for individual controller actions.
# It allows to verify incoming and outgoing XML data and to set different schemas based
# on the request type (GET, PUT, POST, etc.) and direction (in, out). Supported schema
# types are RelaxNG and XML Schema (xsd).

module Suse
  class ValidationError < APIError
    setup 'validation_failed'
  end

  class Validator
    @schema_location = CONFIG['schema_location']

    class << self
      attr_reader :schema_location

      delegate :logger, to: :Rails

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
      def add_schema_mapping(controller, action, opt)
        raise "missing (or wrong) parameters, #{opt.inspect}" unless opt.key?(:request) || opt.key?(:response)

        # logger.debug "add validation mapping: #{controller.inspect}, #{action.inspect} => #{opt.inspect}"

        controller = controller.to_s
        @schema_map ||= {}
        @schema_map[controller] ||= {}
        key = if opt.key?(:method)
                "#{action}-#{opt[:method]}"
              else
                action.to_s
              end
        @schema_map[controller]["#{key}-request"] = opt[:request].to_s if opt[:request] # have a request validation schema?
        @schema_map[controller]["#{key}-response"] = opt[:response].to_s if opt[:response] # have a reponse validate schema?
      end

      # Retrieves the schema filename from the action to schema mapping.
      def get_schema(opt)
        raise 'option hash needs keys :controller and :action' unless opt.key?(:controller) && opt.key?(:action) && opt.key?(:method) && opt.key?(:type)

        c = opt[:controller].to_s
        key = "#{opt[:action]}-#{opt[:method].to_s.downcase}-#{opt[:type]}"
        key2 = "#{opt[:action]}-#{opt[:type]}"

        # logger.debug "checking schema map for controller '#{c}', key: '#{key}'"
        return if @schema_map.nil?
        return unless @schema_map.key?(c)

        @schema_map[c][key] || @schema_map[c][key2]
      end

      # validate ('schema.xsd', '<foo>bar</foo>")
      def validate(opt, content)
        case opt
        when String, Symbol
          schema_file = opt.to_s
        when Hash, ActiveSupport::HashWithIndifferentAccess
          schema_file = get_schema(opt).to_s
        when ActionController::Parameters
          # TODO: Once everything else works test if we can move this to
          #       app/controllers/application_controller.rb:538
          schema_file = get_schema(opt.to_unsafe_h.with_indifferent_access).to_s
        else
          raise "illegal option; need Hash/Symbol/String, seen: #{opt.class.name}"
        end

        schema_base_filename = "#{schema_location}/#{schema_file}"
        schema = nil
        if File.exist?("#{schema_base_filename}.rng")
          schema = Nokogiri::XML::RelaxNG(File.open("#{schema_base_filename}.rng"))
          logger.debug "validating against #{"#{schema_base_filename}.rng"}"
        elsif File.exist?("#{schema_base_filename}.xsd")
          schema = Nokogiri::XML::Schema(File.open("#{schema_base_filename}.xsd"))
          logger.debug "validating against #{"#{schema_base_filename}.xsd"}"
        else
          logger.debug "no schema found, skipping validation for #{opt.inspect}"
          return true
        end

        raise "illegal option; need content for #{schema_file}" if content.nil?

        content = content.to_s
        if content.empty?
          logger.debug "no content, skipping validation for #{schema_file}"
          raise ValidationError, "Document is empty, not allowed for #{schema_file}"
        end

        begin
          doc = Nokogiri::XML(content, &:strict)
        rescue Nokogiri::XML::SyntaxError => e
          raise ValidationError, "#{schema_file} validation error: #{e}"
        end

        nokogiri_xml_syntaxerrors = schema.validate(doc)

        return true if nokogiri_xml_syntaxerrors.empty?

        error_string = nokogiri_xml_syntaxerrors.join("\n")

        logger.debug "validation error: #{error_string}"
        logger.debug "Schema #{schema_file} for: #{content}"
        raise ValidationError, "#{schema_file} validation error: #{error_string}"
      end
    end
  end
end
