class Link < ActiveXML::Base

  # redefine make_stub so that Link.new( :project => 'a', :package => 'b' ) works
  class << self
    def make_stub( opt )
      logger.debug "make stub params: #{opt.inspect}"
      return REXML::Document.new( "<link project=\"#{opt[:linked_project]}\" package=\"#{opt[:linked_package]}\"/>" ).root
    end
  end
  
  def add_patch filename
    if self.has_element? :patches
      patches = data.elements["/link/patches/"]
    else
      patches = REXML::Element.new("patches")
      data.add_element("patches")
    end
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
