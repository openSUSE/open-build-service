xml.comments(@header) do
  render(CommentComponent.with_collection(@comments, obj_is_user: @obj.is_a?(User), builder: xml))
end
