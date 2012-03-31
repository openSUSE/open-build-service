require 'action_view'
require 'nokogiri'

module ActionView
  module Template::Handlers
     class NokogiriBuilder
        class_attribute :default_format
        self.default_format = Mime::XML

        def call(template)
            "xml = ::Nokogiri::XML::Builder.new { |xml|" +
            template.source +
           "}.to_xml;"
        end
    end
  end
end

ActionView::Template.register_template_handler :builder, ActionView::Template::Handlers::NokogiriBuilder.new

