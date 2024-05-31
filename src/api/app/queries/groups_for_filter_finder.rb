class GroupsForFilterFinder
  def initialize(relation = Group.all)
    @relation = relation
  end

  def call
    @relation.joins(:created_notifications)
             .where(notifications: { subscriber: User.session, web: true, delivered: false })
             .distinct
             .pluck(:title)
  end
end
