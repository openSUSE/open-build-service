class Link < ActiveXML::Base

  # redefine make_stub so that Link.new( :project => 'a', :package => 'b' ) works
  class << self
    def make_stub( opt )
      return REXML::Document.new( "<link project=\"#{opt[:project]}\" package=\"#{opt[:package]}\"/>" ).root
    end
  end
  
  def add_patch filename
    patches = @data.elements["/link/patches/"]
    e = REXML::Element.new( "add" )
    e.attributes["name"] = filename
    patches.add_element e
  end

  def has_patch? filename
    if self.has_element? "patches"
      self.patches.each_apply do |patch|
        if patch.name == filename
          return true
        end
      end
    end
    return false
  end
  
  def has_add_patch? filename
    if self.has_element? "patches"
      self.patches.each_add do |patch|
        if patch.name == filename
          return true
        end
      end
    end
    return false
  end
  
end
