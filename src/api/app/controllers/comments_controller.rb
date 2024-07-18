class CommentsController < ApplicationController
  before_action :find_obj, only: %i[index create]

  def index
    comments = @obj.comments.includes(:user)
    comments += Comment.on_actions_for_request(@obj).includes(:user) if @obj.is_a?(BsRequest)
    @comments = comments.sort_by(&:id)
  end

  def create
    comment = @obj.comments.new(body: request.raw_post, user: User.session, parent_id: params[:parent_id])
    authorize comment, :create?
    comment.save!
    render_ok
  end

  def destroy
    comment = Comment.find(params[:id])
    authorize comment, :destroy?
    comment.blank_or_destroy
    render_ok
  end

  def history
    comment = Comment.find(params[:id])
    authorize comment, :history?

    versions = comment.versions

    @header = { comment: comment.id }
    @comments = versions.filter_map(&:reify)
  end

  protected

  def find_obj
    if params[:project]
      if params[:package]
        @obj = Package.get_by_project_and_name(params[:project], params[:package])
        @header = { project: @obj.project.name, package: @obj.name }
      else
        @obj = Project.get_by_name(params[:project])
        @header = { project: @obj.name }
      end
    elsif params[:request_number]
      find_request_or_action
    else
      @obj = User.session
      @header = { user: @obj.login }
    end
  end

  def find_request_or_action
    @obj = BsRequest.find_by!(number: params[:request_number])
    @header = { request: @obj.number }
    return unless params.key?(:parent_id)

    parent_comment = Comment.find_by(id: params[:parent_id])
    raise ActiveRecord::RecordNotFound, "Couldn't find the parent comment with ID #{params[:parent_id]}" if parent_comment.nil?

    # We don't want users to have to know if a parent comment is on a BsRequestAction or a BsRequest.
    # They can simply pass the BsRequest number and we handle this.
    parent_commentable = parent_comment.commentable
    return unless parent_commentable.is_a?(BsRequestAction) && @obj.id == parent_commentable.bs_request_id

    # We want to stick to the same commentable type as the parent comment for the new comment
    @obj = parent_commentable
  end
end
