class Link < ActiveXML::Base

  # redefine make_stub so that Link.new( :project => 'a', :package => 'b' ) works
  class << self
    def make_stub( opt )
      logger.debug "make stub params: #{opt.inspect}"
      doc = XML::Document.new
      doc.root = XML::Node.new 'link'
      doc.root['project'] = opt[:linked_project]
      doc.root['package'] = opt[:linked_package]
      doc.root
    end
  end
  
  def add_patch filename
    if self.has_element? :patches
      patches = ActiveXML::LibXMLNode.new(data.find_first("/link/patches"))
    else
      data.add_element("patches")
    end
    e = patches.add_element "add"
    e["name"] = filename
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
