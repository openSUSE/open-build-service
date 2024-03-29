class RelationshipsFinder
  def initialize(relation = Relationship.all)
    @relation = relation
  end

  def disabled_projects
    @relation.find_by_sql(disabled_projects_query)
  end

  def disabled_projects_query
    <<-END_SQL
          select ur.project_id,ur.user_id,gu.user_id as groups_user_id from flags f
             join relationships ur on ur.project_id=f.project_id
             left join groups_users gu on gu.group_id=ur.group_id
             where f.flag = 'access' and f.status = 'disable'
    END_SQL
  end

  def user_has_role_for_project(project_name, user, role)
    Relationship.joins(:role).joins(:project)
                .where(projects: { name: project_name })
                .where(user: user)
                .exists?('roles.title': role)
  end

  def user_has_role_for_package(package_name, project_name, user, role)
    Relationship.joins(:role).joins(:package).joins('LEFT JOIN projects ON projects.id = packages.project_id')
                .where(packages: { name: package_name })
                .where(projects: { name: project_name })
                .where(user: user)
                .exists?('roles.title': role)
  end
end
