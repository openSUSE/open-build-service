class GroupsForFilterFinder
  def initialize(relation = Group.all)
    @relation = relation
  end

  def call
    @relation.joins(:created_notifications)
             .where(notifications: { subscriber: User.session, delivered: false, web: true })
             .order('groups.title desc').group('groups.title').count # this query returns a sorted-by-title hash like { "reviewers-group" => 1, "iron-maiden" => 3  }
             .sort_by(&:last).reverse.to_h # this sorts the hash by amount: { "iron-maiden" => 3, "reviewers-group" => 1 }
  end
end
