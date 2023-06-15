class BsRequestCleanTasksCacheJob < ApplicationJob
  def perform(request_id)
    request = BsRequest.find(request_id)

    return unless request

    target_package_ids = request.bs_request_actions.with_target_package.pluck(:target_package_id)
    target_project_ids = request.bs_request_actions.with_target_project.pluck(:target_project_id)

    user_ids = Relationship.where(package_id: target_package_ids).or(
      Relationship.where(project_id: target_project_ids)
    ).groups.joins(:groups_users).pluck('groups_users.user_id')

    user_ids += Relationship.where(package_id: target_package_ids).or(
      Relationship.where(project_id: target_project_ids)
    ).users.pluck(:user_id)

    user_ids << User.find_by_login!(request.creator).id

    # rubocop:disable Rails/SkipsModelValidations
    # Skipping Model validations in this case is fine as we only want to touch
    # the associated user models to invalidate the cache keys
    Group.joins(:relationships).where(relationships: { package_id: target_package_ids }).or(
      Group.joins(:relationships).where(relationships: { project_id: target_project_ids })
    ).update_all(updated_at: Time.zone.now)
    User.where(id: user_ids).update_all(updated_at: Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
