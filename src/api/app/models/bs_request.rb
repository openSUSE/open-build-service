class BsRequest < ActiveXML::Base
  default_find_parameter :id

  # override Object#type to get access to the request type attribute
  def type(*args, &block)
    self.value(:type)
  end

  # override Object#id to get access to the request id attribute
  def id(*args, &block)
    self.value(:id)
  end

  def creator
    if self.has_element?(:history)
      e = self.history('@name="new"') 
      e = self.history('@name="review"') if e.nil?
    else
      e = state
    end
    raise RuntimeError, 'broken request: no state/history named "new" or "review"' if e.nil?
    raise RuntimeError, 'broken request: no attribute named "who"' unless e.has_attribute?(:who)
    return e.who
  end

  def is_reviewer? (user)
    return false unless self.has_element?(:review)

    self.each_review do |r|
      if r.has_attribute? 'by_user'
        return true if user.login == r.value("by_user")
      elsif r.has_attribute? 'by_group'
        return true if user.is_in_group? r.value("by_group")
      elsif r.has_attribute? 'by_project'
        if r.has_attribute? 'by_package'
           pkg = DbPackage.find_by_project_and_name r.value("by_project"), r.value("by_package")
           return true if pkg and user.can_modify_package? pkg
        else
           prj = DbProject.find_by_name r.value("by_project")
           return true if prj and user.can_modify_project? prj
        end
      end
    end

    return false
  end

  def initialize( _data )
    super(_data)

    if self.has_element? 'submit' and self.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = self.submit.dump_xml
      node.sub!('<submit ', '<action ')
      puts node
      self.delete_element('submit')
      node = self.add_node(node)
      node.set_attribute('type', 'submit')
      self.delete_attribute('type')
    end
  end

end
