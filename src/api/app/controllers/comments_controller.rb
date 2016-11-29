class CommentsController < ApplicationController
  before_action :find_obj, only: [:show_comments, :create]
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def show_comments
    @comments = @obj.comments.order(:id)
    render "show_#{@template}_comments"
  end

  def create
    @obj.comments.create!(body: request.raw_post, user: User.current)
    render_ok
  end

  def destroy
    comment = Comment.find params[:id]
    authorize comment
    comment.blank_or_destroy
    render_ok
  end

  protected

  def not_authorized
    raise NoPermission.new "No permission to delete #{params[:id]}"
  end

  def find_obj
    if params[:project]
      if params[:package]
        @template = 'package'
        @obj = Package.get_by_project_and_name(params[:project], params[:package])
      else
        @template = 'project'
        @obj = Project.get_by_name(params[:project])
      end
    else
      @template = 'request'
      @obj = BsRequest.find_by_number!(params[:id])
    end
  end
end
