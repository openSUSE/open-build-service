class Webui::Statusmessage < Webui::Node

  default_find_parameter :id

  def self.make_stub( opt )
    doc = ActiveXML::Node.new "<message/>"
    doc.text = opt[:message]
    doc.set_attribute('severity', opt[:severity]) if opt[:severity]
    return doc
  end

  def id
    @init_options[:id]
  end
end
