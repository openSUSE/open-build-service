class Collection < ActiveXML::Base
  def is_empty?
    return !self.has_elements?
  end
end
