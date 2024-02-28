module Webui::CommentsHelper
  def comment_user_role_titles(comment)
    roles = []

    case
    when comment.commentable.is_a?(BsRequest)
      roles = roles_for_request(comment)
    when comment.commentable.is_a?(Project)
      roles.push('maintainer') if roles_for_project(comment).any?
    when comment.commentable.is_a?(Package)
      roles.push('maintainer') if roles_for_package(comment).any?
      roles.push('project maintainer') if roles_for_project(comment).any?
    end

    roles
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
    roles.push('author') if comment.commentable.creator == comment.user.login
    roles.push('reviewer') if comment.commentable.reviews.pluck(:user_id).include?(comment.user.id) ||
                              comment.commentable.reviews.pluck(:group_id).intersect?(comment.user.groups.ids)
    source_roles = []
    target_roles = []
    comment.commentable.bs_request_actions.each do |action|
      source_roles += Relationship.joins(:role).joins(:project)
                                  .where(projects: { name: action.source_project })
                                  .where(user: comment.user)
                                  .where('roles.title': 'maintainer')
                                  .pluck('roles.title')
                                  .union(Relationship.joins(:role).joins(:package)
                                                     .where(packages: { name: action.source_package })
                                                     .where(user: comment.user)
                                                     .where('roles.title': 'maintainer')
                                                     .pluck('roles.title'))

      target_roles += Relationship.joins(:role).joins(:project)
                                  .where(projects: { name: action.target_project })
                                  .where(user: comment.user)
                                  .where('roles.title': 'maintainer')
                                  .pluck('roles.title')
                                  .union(Relationship.joins(:role).joins(:package)
                                                     .where(packages: { name: action.target_package })
                                                     .where(user: comment.user)
                                                     .where('roles.title': 'maintainer')
                                                     .pluck('roles.title'))
    end

    roles.push('source maintainer') if source_roles.any?
    roles.push('target maintainer') if target_roles.any?

    roles
  end
end
