class CommentHistoryComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/comment_history_component/preview
  def preview
    comment = Comment.last
    comment.body += 'a'
    comment.save!
    render(CommentHistoryComponent.new(comment))
  end
end
