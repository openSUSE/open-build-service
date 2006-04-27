class Link < ActiveXML::Base
  
  def add_patch filename
    patches = @data.elements["/link/patches/"]
    e = REXML::Element.new( "add" )
    e.attributes["name"] = filename
    patches.add_element e
  end

  def has_patch? filename
    self.patches.each_add do |patch|
      if patch.name == filename
        return true
      end
    end
    return false
  end
  
end
