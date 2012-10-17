class Statusmessage < ActiveXML::Node

  default_find_parameter :id

  class << self

    def make_stub( opt )
      doc = ActiveXML::Node.new "<message/>"
      doc.text = opt[:message]
      doc.set_attribute('severity', opt[:severity]) if opt[:severity]
      return doc
    end

  end #self

  def id
    @init_options[:id]
  end
end
