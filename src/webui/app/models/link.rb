class Link < ActiveXML::Node

  # redefine make_stub so that Link.new( :project => 'a', :package => 'b' ) works
  class << self
    def make_stub( opt )
      logger.debug "make stub params: #{opt.inspect}"
      doc = ActiveXML::Node.new "<link/>"
      doc.set_attribute('project', opt[:linked_project])
      doc.set_attribute('package', opt[:linked_package])
      doc
    end
  end

  # an 'add' patch adds the patch file to the package and uses it from the specfile
  def add_patch filename
    add_element "patches" if !self.has_element? :patches
    patches = ActiveXML::Node.new(data.find_first("/link/patches"))
    #TODO: We need to add it a the correct place, but add_element cannot handle that
    patches.add_element "add", 'name' => filename
  end

  # an 'apply' patch patches directly the sources of the package before building
  def apply_patch filename
    add_element "patches" if !self.has_element? :patches
    patches = ActiveXML::Node.new(data.find_first("/link/patches"))
    #TODO: We need to add it a the correct place, but add_element cannot handle that
    patches.add_element "apply", 'name' => filename
  end

  def set_branch branch
    add_element "patches" if !self.has_element? :patches
    if branch
      patches.add_element "branch"
    else
      delete_element "patches/branch"
    end
  end

  def set_revision rev
    if rev
      data.attributes["rev"] = rev
    else
      delete_attribute "rev"
    end
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
        if patch.has_attribute? 'name' and (patch.name == filename)
          return true
        end
      end
    end
    return false
  end
  
end
