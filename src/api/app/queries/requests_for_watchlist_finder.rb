class RequestsForWatchlistFinder
  def initialize(relation = BsRequest.joins(:watched_items))
    @relation = relation
  end

  def call(user)
    @relation.where(watched_items: { user: user }).order('number DESC')
  end
end
