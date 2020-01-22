class RelationshipsFinder
  def initialize(relation = Relationship.all)
    @relation = relation
  end

  def disabled_projects
    @relation.find_by_sql(disabled_projects_query)
  end

  def disabled_projects_query
    <<-END_SQL
          SELECT ur.project_id, ur.user_id from flags f,
                relationships ur where f.flag = 'access' and f.status = 'disable' and ur.project_id = f.project_id
    END_SQL
  end
end
