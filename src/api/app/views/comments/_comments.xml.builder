comments.each do |comment|
  comment.to_xml(builder, @obj.is_a?(User))
end
