class ProjectsForWatchlistFinder
  def initialize(relation = Project.joins(:watched_items))
    @relation = relation
  end

  def call(user)
    @relation.where(watched_items: { user: user }).order('LOWER(projects.name), projects.name')
  end
end
