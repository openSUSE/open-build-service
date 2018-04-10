# frozen_string_literal: true

require 'action_view'
require 'nokogiri'

module ActionView
  module Template::Handlers
    class NokogiriBuilder
      class_attribute :default_format
      self.default_format = Mime[:xml]

      def call(template)
        'xml = ::Nokogiri::XML::Builder.new { |xml|' +
          template.source +
          "}.to_xml :indent => 2, :encoding => 'UTF-8',
            :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT;"
      end
    end
  end
end

ActionView::Template.register_template_handler :builder, ActionView::Template::Handlers::NokogiriBuilder.new
