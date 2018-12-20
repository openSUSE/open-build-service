obj_is_user = @obj.is_a?(User)
xml.comments(@header) do
  @comments.each do |comment|
    comment.to_xml(xml, obj_is_user)
  end
end
