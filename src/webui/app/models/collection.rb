class Collection < ActiveXML::Base
  def is_empty?
    puts "empty"
    return !self.has_elements?
  end
end
