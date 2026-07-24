class UnknownAttributeTypeError < APIError
  setup 'unknown_attribute_type', 404, 'Unknown Attribute Type'
end
