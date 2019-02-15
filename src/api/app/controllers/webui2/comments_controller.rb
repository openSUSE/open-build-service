module Webui2::CommentsController
  def webui2_create
    comment = @commented.comments.new(permitted_params)
    User.current.comments << comment
    @commentable = comment.commentable

    respond_to do |format|
      if comment.save
        flash.now[:notice] = 'Comment created successfully.'
        status = :ok
      else
        flash.now[:error] = "Failed to create comment: #{comment.errors.full_messages.to_sentence}."
        status = :unprocessable_entity
      end
      format.html do
        render(partial: 'webui2/webui/comment/comment_list', locals: { commentable: @commentable }, status: status)
      end
    end
  end

  def webui2_destroy
    comment = Comment.find(params[:id])
    authorize comment, :destroy?
    @commentable = comment.commentable

    respond_to do |format|
      if comment.blank_or_destroy
        flash.now[:notice] = 'Comment deleted successfully.'
        status = :ok
      else
        flash.now[:error] = "Failed to delete comment: #{comment.errors.full_messages.to_sentence}."
        status = :unprocessable_entity
      end
      format.html do
        render(partial: 'webui2/webui/comment/comment_list', locals: { commentable: @commentable }, status: status)
      end
    end
  end
end
