class CommentsController < ApplicationController

  before_filter :find_request, only: [:show_request_comments]
  before_filter :require_login, only: [:delete_comment, :create_request_comment]

  def find_request
    @obj = BsRequest.find(params[:id])
  end

  def show_request_comments
    show_comments
  end

  before_filter :find_package, only: [:show_package_comments]

  def find_package
    @obj = Package.get_by_project_and_name(params[:project], params[:package])
  end

  def show_package_comments
    show_comments
  end

  before_filter :find_project, only: [:show_project_comments]

  def find_project
    @obj = Project.get_by_name(params[:project])
  end

  def show_project_comments
    show_comments
  end

  def show_comments
    @comments = @obj.comments.order(:id)
  end

  def create_request_comment
    req = BsRequest.find params[:id]

    req.comment_class.create!(body: request.raw_post, user: User.current, bs_request_id: req.id)
    render_ok
  end

  def delete_comment
    comment = Comment.find params[:id]
    unless comment.check_delete_permissions
      raise NoPermission.new "No permission to delete #{params[:id]}"
    end
    comment.destroy
    render_ok
  end

end
