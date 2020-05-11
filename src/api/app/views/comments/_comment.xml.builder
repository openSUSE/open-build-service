comment_presenter = CommentsControllerPresenters::CommentPresenter.new(comment, obj_is_user)

builder.comment_(comment_presenter.attributes) do
  builder.text(comment_presenter.body)
end
