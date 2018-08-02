module Webui2::CommentsController
  def webui2_create
    comment = @commented.comments.new(permitted_params)
    User.current.comments << comment
    # required for the form construction
    @comment = Comment.new

    respond_to do |format|
      if comment.save
        format.html { redirect_back(fallback_location: root_path, notice: 'Comment was successfully created.') }
        format.json { render json: 'ok' }
        format.js { render partial: 'webui2/webui/comment/show', locals: { commentable: comment.commentable }, status: :ok }
      else
        format.html { redirect_back(fallback_location: root_path, error: "Comment can't be saved: #{comment.errors.full_messages.to_sentence}.") }
        format.json { render json: comment.errors, status: :unprocessable_entity }
      end
    end
  end
end
