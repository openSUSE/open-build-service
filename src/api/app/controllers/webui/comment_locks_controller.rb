class Webui::CommentLocksController < Webui::WebuiController
  before_action :set_commentable

  def create
    authorize @commentable, policy_class: CommentLockPolicy

    @comment_lock = CommentLock.new(commentable: @commentable, moderator: User.session!)
    if @comment_lock.save
      flash[:success] = "Comments for #{params[:commentable_type]} locked"
    else
      flash[:error] = @comment_lock.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @commentable, policy_class: CommentLockPolicy

    @comment_lock = CommentLock.find(params[:comment_lock_id])
    if @comment_lock.destroy
      flash[:success] = "Comments for #{params[:commentable_type]} unlocked"
    else
      flash[:error] = @comment_lock.errors.full_messages.to_sentence
    end
  end

  private

  def set_commentable
    commentable_type = case params[:commentable_type]
                       when 'BsRequest'
                         BsRequest
                       when 'Package'
                         Package
                       when 'Project'
                         Project
                       end
    raise APIError, "Unknown commentable type '#{params[:commentable_type]}'" if commentable_type.nil?

    @commentable = commentable_type.find(params[:commentable_id])
  end
end
