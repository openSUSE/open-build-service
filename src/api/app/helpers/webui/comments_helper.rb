module Webui::CommentsHelper
  def comment_user_role_titles(comment)
    roles = []

    case
    when comment.commentable.is_a?(BsRequest)
      roles = roles_for_request(comment)
    when comment.commentable.is_a?(Project)
      roles << 'maintainer' if roles_for_project(comment).any?
    when comment.commentable.is_a?(Package)
      roles << 'maintainer' if roles_for_package(comment).any?
      roles << 'project maintainer' if roles_for_project(comment).any?
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
    roles << 'author' if comment.commentable.creator == comment.user.login
    roles << 'reviewer' if review_assigned_to_user(comment)
    roles << 'source maintainer' if comment.commentable.bs_request_actions.any? { |action| source_maintainer(action, comment.user) }
    roles << 'target maintainer' if comment.commentable.bs_request_actions.any? { |action| target_maintainer(action, comment.user) }
    roles
  end

  def review_assigned_to_user(comment)
    comment.commentable.reviews.map(&:user).include?(comment.user) || comment.commentable.reviews.pluck(:group_id).intersect?(comment.user.groups.ids)
  end

  def source_maintainer(action, user)
    RelationshipsFinder.new.user_has_role_for_project(action.source_project, user, 'maintainer') ||
      RelationshipsFinder.new.user_has_role_for_package(action.source_package, action.source_project, user, 'maintainer')
  end

  def target_maintainer(action, user)
    RelationshipsFinder.new.user_has_role_for_project(action.target_project, user, 'maintainer') ||
      RelationshipsFinder.new.user_has_role_for_package(action.target_package, action.target_project, user, 'maintainer')
  end
end
