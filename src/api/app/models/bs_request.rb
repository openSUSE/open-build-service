class BsRequest < ActiveXML::Base
  default_find_parameter :id

  # override Object#type to get access to the request type attribute
  def type(*args, &block)
    method_missing :type, *args, &block
  end
end
