require 'xml'

class Rating < ActiveXML::Base

  class << self

    def make_stub( opt )
      doc = XML::Document.new
      doc.root = XML::Node.new 'rating'
      doc.root.content = opt[:score]
      doc.root
    end

  end #self


end
