begin
   doc = Nokogiri::XML(File.open("#{RAILS_ROOT}/lib/xml/xhtml1-strict.xsd"))
   XHTML_XSD = Nokogiri::XML::Schema.from_document doc
end

