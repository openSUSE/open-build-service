class BsRequest < ActiveXML::Base
  default_find_parameter :id

  # override Object#type to get access to the request type attribute
  def type(*args, &block)
    data[:type]
  end

  # override Object#id to get access to the request id attribute
  def id(*args, &block)
    data[:id]
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
        return true if user.login == r.data.attributes["by_user"]
      elsif r.has_attribute? 'by_group'
        return true if user.is_in_group? r.data.attributes["by_group"]
      end
    end

    return false
  end

  def initialize( _data )
    super(_data)

    if self.has_element? 'submit' and self.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = self.submit
      node.data.name = 'action'
      node.data.attributes['type'] = 'submit'
      self.delete_attribute('type')
    end
  end

end
