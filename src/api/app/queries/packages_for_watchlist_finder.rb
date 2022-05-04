class PackagesForWatchlistFinder
  def initialize(relation = Package.joins(:watched_items))
    @relation = relation
  end

  def call(user)
    @relation.joins(:project).where(watched_items: { user: user })
             .order('LOWER(projects.name), projects.name, LOWER(packages.name), packages.name')
  end
end
