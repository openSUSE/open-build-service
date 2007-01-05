require 'rexml/document'
include REXML

class Tag < ActiveXML::Base
#
##TODO use ActiveXML::Taglist , the problem is the constructor
#

  class << self
    
     # redefine make_stub to achieve taglist needs 
    def make_stub( opt )                  
      
      xml = REXML::Document.new
      xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
      xml.add_element( REXML::Element.new("tags") )
      if opt[:project]
        xml.root.add_attribute Attribute.new("project", opt[:project])
      else
        xml.root.add_attribute Attribute.new("project", opt[:name])
      end
      
      opt[:tag].split(" ").each do |tag|
          tag = tag.strip
          element = REXML::Element.new( 'tag' )
          element.add_attribute Attribute.new('name', tag)
          xml.root.add_element(element)      
      end
      xml
   end
  end #self

end #class
