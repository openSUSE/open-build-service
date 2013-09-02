class Webui::CommentsController < Webui::BaseController

  before_filter :require_user
  before_filter :require_body_and_title, only: [:packages_new, :projects_new, :requests_new]

  class CommentNoPermission < APIException
  end

  def require_body_and_title
    required_fields :body, :title
    return true
  end

  def render_thread
    sort_comments
    render :json => @comments_as_thread
  end

  def packages
    package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
    @comments = CommentPackage.where(package_id: package.id)
    render_thread
  end

  def projects
    project = Project.get_by_name(params[:project])
    @comments = CommentProject.where(project_id: project.id)
    render_thread
  end

  def requests
    @comments = CommentRequest.where(bs_request_id: params[:id])
    render_thread
  end

  def packages_new
    required_parameters :project, :package

    CommentPackage.save(params)
    render_ok
  end

  def projects_new
    required_parameters :project

    CommentProject.save(params)
    render_ok
  end

  def requests_new
    required_parameters :id

    CommentRequest.save(params)
    render_ok
  end

  def delete
    required_parameters :comment_id
    permission_check!(params)
    destroy_or_remove(params)
    render_ok
  end

  def require_user
    params[:user] = User.current.login
  end

  private

  def permission_check!(params)
    delete = false
    comment = Comment.find(params[:comment_id])
    package = Package.get_by_project_and_name(params[:project], params[:package]) if params[:package]
    project = Project.get_by_name(params[:project]) if params[:project]
    request = BsRequest.find(params[:id]) if params[:id]

    # Users can always delete their own comments
    if User.current.login == comment.user
      delete = true
    end
    # Admins can always delete all comments
    if User.current.is_admin?
      delete = true
    end
    # If you can change the project, you can delete the comment
    if project and User.current.has_local_permission?("change_project", project)
      delete = true
    end
    # If you can change the package, you can delete the comment
    if package and User.current.has_local_permission?("change_package", package)
      delete = true
    end
    # If you can review or if you are maintainer of the target of the request, you can delete the comment
    if request and (request.is_reviewer?(User.current) || request.is_target_maintainer?(User.current))
      delete = true
    end
    unless delete
      raise CommentNoPermission.new, "You don't have the permissions to modify the content."
    end
  end

  def destroy_or_remove(params)
    children = Comment.where("parent_id = ?", params[:comment_id])
    if children.length < 1
      Comment.destroy(params[:comment_id])
    else
      Comment.remove(params)
    end
  end

  def sort_comments
    @all_comments = Hash.new
    @all_comments[:parents] = []
    @all_comments[:children] = []

    # separate parents from children. How cruel, I know.
    @comments.each do |com|
      # No valid parent
      if com['parent_id'].present? && Comment.exists?(com['parent_id'])
        @all_comments[:children] << [com['title'], com['body'], com['user'], com['parent_id'], com['id'], com['created_at']]
      else
        @all_comments[:parents] << [com['title'], com['body'], com['id'], com['user'], com['created_at']]
      end
    end

    @all_comments[:parents].sort_by! { |c| c[4] } # sorting by created_at
    @all_comments[:children].sort_by! { |c| c[4] } # sorting by created_at

    thread_comments
  end

  def thread_comments
    @comments_as_thread = []
    # now pushing sorted and final list of first/top/parent level comments into to a hash to
    @all_comments[:parents].each do |first_level|
      @comments_as_thread << {
          created_at: first_level[4],
          id: first_level[2],
          title: first_level[0],
          body: first_level[1],
          parent_id: nil,
          user: first_level[3],
          children: find_children(first_level[2])
      }
    end
  end

  def find_children(parent_id = nil)
    return [] unless parent_id
    current_children = []

    # get children of current top comment
    child_comments = @all_comments[:children].select do |c|
      c[3] == parent_id
    end

    # pushing children coments into hash

    child_comments.each do |child|
      current_children << {
          created_at: child[5],
          id: child[4],
          title: child[0],
          body: child[1],
          parent_id: child[3],
          user: child[2],
          children: find_children(child[4])
      }
    end
    return current_children
  end
end
