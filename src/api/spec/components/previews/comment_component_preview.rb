class CommentComponentPreview < ViewComponent::Preview
  def with_default_content
    render(CommentComponent.new(comment: create(:comment), obj_is_user: create(:confirmed_user)))
  end
end
