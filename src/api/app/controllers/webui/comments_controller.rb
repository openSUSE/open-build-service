class Webui::CommentsController < Webui::WebuiController
  before_action :require_login
  before_action :set_commented, only: :create
  before_action :set_comment, only: [:moderate, :history]

  def create
    return commented_unavailable if @commented.nil?

    @comment = @commented.comments.new(permitted_params)
    authorize @comment, :create?
    User.session!.comments << @comment
    @commentable = @comment.commentable

    status = if @comment.save
               flash.now[:success] = 'Comment created successfully.'
               :ok
             else
               flash.now[:error] = "Failed to create comment: #{@comment.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

    if Flipper.enabled?(:request_show_redesign, User.session) && ['BsRequest', 'BsRequestAction'].include?(@comment.commentable_type)
      render_timeline
    else
      render(partial: 'webui/comment/comment_list',
             locals: { commentable: @commentable, diff_ref: @comment.root.diff_ref },
             status: status,
             root_comment: @comment.root)
    end
  end

  def update
    @comment = Comment.find(params[:id])
    authorize @comment, :update?
    @comment.assign_attributes(permitted_params)

    status = if @comment.save
               flash.now[:success] = 'Comment updated successfully.'
               :ok
             else
               flash.now[:error] = "Failed to update comment: #{@comment.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

   
    if Flipper.enabled?(:request_show_redesign, User.session) && ['BsRequest', 'BsRequestAction'].include?(@comment.commentable_type)
      render_timeline
    else
      respond_to do |format|
        format.html do
          render(partial: 'webui/comment/comment_list',
                 locals: { commentable: @comment.commentable, diff_ref: @comment.root.diff_ref },
                 status: status)
        end
      end
    end
  end

  # TODO: Once we ship this and we remove the flipper check, this methods will
  # get simpler, so I'll just shut rubocop up for now.
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def destroy
    @comment = Comment.find(params[:id])
    authorize @comment, :destroy?
    @commentable = @comment.commentable

    status = if @comment.blank_or_destroy
               flash.now[:success] = 'Comment deleted successfully.'
               :ok
             else
               flash.now[:error] = "Failed to delete comment: #{@comment.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

    if Flipper.enabled?(:request_show_redesign, User.session) && ['BsRequest', 'BsRequestAction'].include?(@comment.commentable_type)
      render_timeline
    else
      render(partial: 'webui/comment/comment_list', locals: { commentable: @commentable, diff_ref: @comment.root.diff_ref }, status: status)
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  def preview
    markdown = helpers.render_as_markdown(permitted_params[:body])
    respond_to do |format|
      format.json { render json: { markdown: markdown } }
    end
  end

  def moderate
    authorize @comment, :moderate?

    state = ActiveModel::Type::Boolean.new.cast(params[:moderation_state])

    status = if @comment.moderate(state)
               flash.now[:success] = 'Comment moderated successfully.'
               :ok
             else
               flash.now[:error] = "Failed to moderate comment: #{@comment.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

    if Flipper.enabled?(:request_show_redesign, User.session) && ['BsRequest', 'BsRequestAction'].include?(@comment.commentable_type)
      render_timeline
    else
      render(partial: 'webui/comment/comment_list',
             locals: { commentable: @comment.commentable, diff_ref: @comment.root.diff_ref },
             status: status,
             root_comment: @comment.root)
    end
  end

  def history
    authorize @comment, :history?

    @version = @comment.versions.find(params[:version_id])
    respond_to do |format|
      format.js { render 'webui/comment/history' }
    end
  end

  def render_timeline
    bs_request = @comment.commentable_type == 'BsRequestAction' ? @comment.commentable.bs_request : @comment.commentable
    target_project = Project.find_by_name(bs_request.target_project_name)
    request_reviews = bs_request.reviews.for_non_staging_projects(target_project)
    render(partial: 'webui/comment/render_timeline', locals: {bs_request: bs_request, request_reviews: request_reviews})
  end

  private

  def permitted_params
    params.require(:comment).permit(:body, :parent_id, :diff_ref)
  end

  # FIXME: Use this function for the rest of the actions
  def set_comment
    @comment = Comment.find(params[:comment_id] || params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    render partial: 'layouts/webui/flash'
  end

  def set_commented
    @commentable_type = [Project, Package, BsRequest, BsRequestActionSubmit].find { |klass| klass.name == params[:commentable_type] }
    @commented = @commentable_type&.find_by(id: params[:commentable_id])
    return if @commentable_type.present?

    flash[:error] = "Invalid commentable #{params[:commentable_type]} supplied."
    render partial: 'layouts/webui/flash'
  end

  def commented_unavailable
    flash.now[:error] = "Failed to create comment: This #{@commentable_type.name.downcase} does not exist anymore."
    render partial: 'layouts/webui/flash'
  end
end
