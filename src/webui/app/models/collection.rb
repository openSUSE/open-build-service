class Collection < ActiveXML::Node
  def is_empty?
    return !self.has_elements?
  end
end
