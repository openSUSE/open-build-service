class ProjectsForFilterFinder
  def initialize(relation = Project.all)
    @relation = relation
  end

  def call
    @relation.joins(:notifications)
             .where(notifications: { subscriber: User.session, web: true })
             .distinct
             .order('name asc')
             .pluck(:name)
  end
end
