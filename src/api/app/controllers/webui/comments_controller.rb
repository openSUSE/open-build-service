class Webui::CommentsController < Webui::WebuiController
  include Webui2::CommentsController

  before_action :require_login
  before_action :find_commentable, only: :create

  def create
    return if switch_to_webui2
    comment = @commented.comments.new(permitted_params)
    User.current.comments << comment

    # required for the form construction
    @comment = Comment.new

    respond_to do |format|
      if comment.save
        format.html { redirect_back(fallback_location: root_path, notice: 'Comment was successfully created.') }
        format.json { render json: 'ok' }
        format.js { render partial: 'webui/comment/show', locals: { commentable: comment.commentable }, status: :ok }
      else
        format.html { redirect_back(fallback_location: root_path, error: "Comment can't be saved: #{comment.errors.full_messages.to_sentence}.") }
        format.json { render json: comment.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    return if switch_to_webui2

    comment = Comment.find(params[:id])
    authorize comment, :destroy?

    respond_to do |format|
      if comment.blank_or_destroy
        flash[:notice] = 'Comment deleted successfully.'
        format.json { render json: { flash: render_flash } }
      else
        flash[:error] = "Failed to delete comment: #{comment.errors.full_messages.to_sentence}."
        format.json { render json: { flash: render_flash }, status: :unprocessable_entity }
      end
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  private

  def render_flash
    render_to_string(
      partial: 'layouts/webui/flash',
      formats: :html,
      layout: false,
      object: flash
    )
  end

  def permitted_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def find_commentable
    commentable = [Project, Package, BsRequest].find { |klass| klass.name == params[:commentable_type] }
    @commented = commentable.find(params[:commentable_id])
  end
end
