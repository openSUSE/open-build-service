class MaintainedPackagesByUserFinder
  def initialize(user)
    @user = user
  end

  def call
    packages_maintained_by_the_user
  end

  # private

  def maintainer_role_id
    Role.hashed['maintainer'].id
  end

  def involved_projects_ids
    @user.involved_projects.select(:id)
  end

  def packages_by_role
    Package.left_outer_joins(:relationships).where('relationships.role_id' => maintainer_role_id)
  end

  def packages_maintained_by_the_user
    packages_by_role.where([
                             '(relationships.user_id = ?) OR ' \
                             '(relationships.user_id is null AND packages.project_id in (?) )', @user.id, involved_projects_ids
                           ])
  end
end
