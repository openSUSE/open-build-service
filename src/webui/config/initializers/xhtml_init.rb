doc = Nokogiri::XML(File.open("#{Rails.root}/lib/xml/xhtml1-strict.xsd"))
XHTML_XSD = Nokogiri::XML::Schema.from_document doc
doc = nil
