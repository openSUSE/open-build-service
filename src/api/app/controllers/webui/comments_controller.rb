class Webui::CommentsController < Webui::WebuiController
  before_action :require_login
  before_action :find_commentable, only: :create

  def create
    comment = @commented.comments.new(permitted_params)
    User.current.comments << comment

    respond_to do |format|
      if comment.save
        format.html { redirect_back(fallback_location: root_path, notice: 'Comment was successfully created.') }
        format.json { render json: 'ok' }
      else
        format.html { redirect_back(fallback_location: root_path, error: "Comment can't be saved: #{comment.errors.full_messages.to_sentence}.") }
        format.json { render json: comment.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    comment = Comment.find(params[:id])
    authorize comment, :destroy?
    comment.blank_or_destroy

    respond_to do |format|
      format.js { render json: 'ok' }
      format.html do
        flash[:notice] = 'Comment deleted successfully'
      end
    end
    redirect_back(fallback_location: root_path)
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
