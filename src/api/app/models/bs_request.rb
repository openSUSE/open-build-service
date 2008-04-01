class BsRequest < ActiveXML::Base
  default_find_parameter :id

  # override Object#type to get access to the request type attribute
  def type(*args, &block)
    method_missing :type, *args, &block
  end

  # override Object#id to get access to the request id attribute
  def id(*args, &block)
    method_missing :id, *args, &block
  end
end
