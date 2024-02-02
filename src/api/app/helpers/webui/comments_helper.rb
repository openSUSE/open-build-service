module Webui::CommentsHelper
  def comment_user_role_titles(comment)
    roles = comment.user.roles.global.pluck(:title)

    roles += roles_for_project(comment) if comment.commentable.is_a?(Project)

    roles += roles_for_package(comment) if comment.commentable.is_a?(Package)

    roles += roles_for_request(comment) if comment.commentable.is_a?(BsRequest)

    roles.uniq
  end

  private

  def roles_for_project(comment)
    comment.user.relationships.where(project_id: comment.commentable.id)
           .joins(:role)
           .pluck(:title)
  end

  def roles_for_package(comment)
    comment.user.relationships.where(package_id: comment.commentable.id)
           .joins(:role)
           .pluck(:title)
  end

  def roles_for_request(comment)
    roles = []
    roles << 'Submitter' if comment.commentable.creator == comment.user.login
    comment.commentable.bs_request_actions.inject(roles) do |acc, action|
      acc += Relationship
             .joins(:role)
             .joins(:project)
             .where(projects: { name: action.target_project })
             .where(user: comment.user)
             .pluck('roles.title')

      acc + Relationship
            .joins(:role)
            .joins(:package)
            .where(packages: { name: action.target_package })
            .where(user: comment.user)
            .pluck('roles.title')
    end
  end
end
