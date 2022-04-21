class WatchlistFinder
  def initialize(relation = WatchedItem.all)
    @relation = relation
  end

  def watchlist_projects(user)
    @relation.includes(:watchable).where(user: user, watchable_type: 'Project').collect(&:watchable)
  end

  def watchlist_packages(user)
    @relation.includes(:watchable).where(user: user, watchable_type: 'Package').collect(&:watchable)
  end

  def watchlist_requests(user)
    @relation.includes(:watchable).where(user: user, watchable_type: 'BsRequest').collect(&:watchable)
  end
end
