require 'xml'

class Statusmessage < ActiveXML::Base

  default_find_parameter :id

  class << self

    def make_stub( opt )
      logger.debug "--> creating stub element for #{self.name}, arguments: #{opt.inspect}"
      doc = XML::Document.new
      doc.root = XML::Node.new 'message'
      doc.root.content = opt[:message]
      doc.root['severity'] = opt[:severity].to_s if opt[:severity]
      return doc.root
    end

  end #self

  def id
    @init_options[:id]
  end
end
