class Webui::CommentLocksController < Webui::WebuiController
  before_action :set_commentable

  def create
    authorize @commentable, policy_class: CommentLockPolicy

    @comment_lock = CommentLock.new(commentable: @commentable, moderator: User.session)
    if @comment_lock.save
      flash[:success] = "Comments for #{comment_lock_params[:commentable_type]} locked"
    else
      flash[:error] = @comment_lock.errors.full_messages.to_sentence
    end

    redirect_back_or_to root_path
  end

  def destroy
    authorize @commentable, policy_class: CommentLockPolicy

    @comment_lock = CommentLock.find(params[:comment_lock_id])
    if @comment_lock.destroy
      flash[:success] = "Comments for #{comment_lock_params[:commentable_type]} unlocked"
    else
      flash[:error] = @comment_lock.errors.full_messages.to_sentence
    end

    redirect_back_or_to root_path
  end

  private

  def comment_lock_params
    params.require(:comment_lock).permit(:commentable_type, :commentable_id)
  end

  def set_commentable
    commentable_type = case comment_lock_params[:commentable_type]
                       when 'BsRequest'
                         BsRequest
                       when 'Package'
                         Package
                       when 'Project'
                         Project
                       end
    raise APIError, "Unknown commentable type '#{comment_lock_params[:commentable_type]}'" if commentable_type.nil?

    @commentable = commentable_type.find(comment_lock_params[:commentable_id])
  end
end
