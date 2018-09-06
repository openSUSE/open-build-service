module Webui2::CommentsController
  def webui2_create
    comment = @commented.comments.new(permitted_params)
    User.current.comments << comment
    # required for the form construction
    @comment = Comment.new
    @commentable = comment.commentable

    respond_to do |format|
      if comment.save
        flash.now[:notice] = 'Comment created successfully.'
        status = :ok
      else
        flash.now[:error] = "Failed to create comment: #{comment.errors.full_messages.to_sentence}."
        status = :unprocessable_entity
      end
      format.js { render 'webui2/webui/comment/create_or_destroy', status: status }
    end
  end

  def webui2_destroy
    comment = Comment.find(params[:id])
    authorize comment, :destroy?
    @commentable = comment.commentable
    @comment = Comment.new # Needed for the new comment form

    respond_to do |format|
      if comment.blank_or_destroy
        flash.now[:notice] = 'Comment deleted successfully.'
        status = :ok
      else
        flash.now[:error] = "Failed to delete comment: #{comment.errors.full_messages.to_sentence}."
        status = :unprocessable_entity
      end
      format.js { render 'webui2/webui/comment/create_or_destroy', status: status }
    end
  end
end
