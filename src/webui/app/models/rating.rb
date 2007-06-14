require 'rexml/document'
class Rating < ActiveXML::Base


  class << self

    def make_stub( opt )
      doc = REXML::Document.new
      doc << XMLDecl.new( 1.0, 'UTF-8', 'no' )
      doc.add_element( REXML::Element.new( 'rating' ) )
      doc.root.add_text( opt[:score] )
      return doc
    end

  end #self


end
