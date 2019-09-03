class Webui::CommentsController < Webui::WebuiController
  before_action :require_login
  before_action :find_commentable, only: :create

  def create
    switch_to_webui2

    comment = @commented.comments.new(permitted_params)
    User.session!.comments << comment
    @commentable = comment.commentable

    respond_to do |format|
      if comment.save
        flash.now[:success] = 'Comment created successfully.'
        status = :ok
      else
        flash.now[:error] = "Failed to create comment: #{comment.errors.full_messages.to_sentence}."
        status = :unprocessable_entity
      end
      format.html do
        render(partial: 'webui/comment/comment_list', locals: { commentable: @commentable }, status: status)
      end
    end
  end

  def destroy
    switch_to_webui2

    comment = Comment.find(params[:id])
    authorize comment, :destroy?
    @commentable = comment.commentable

    respond_to do |format|
      if comment.blank_or_destroy
        flash.now[:success] = 'Comment deleted successfully.'
        status = :ok
      else
        flash.now[:error] = "Failed to delete comment: #{comment.errors.full_messages.to_sentence}."
        status = :unprocessable_entity
      end
      format.html do
        render(partial: 'webui/comment/comment_list', locals: { commentable: @commentable }, status: status)
      end
    end
  end

  private

  def permitted_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def find_commentable
    commentable = [Project, Package, BsRequest].find { |klass| klass.name == params[:commentable_type] }
    @commented = commentable.find(params[:commentable_id])
  end
end
