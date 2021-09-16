class ProjectsForFilterFinder
  def initialize(relation = Project.all)
    @relation = relation
  end

  def call
    @relation.joins(:notifications)
             .where(notifications: { subscriber: User.session, delivered: false, web: true })
             .order('name desc').group(:name).count # this query returns a sorted-by-name hash like { "home:b" => 1, "home:a" => 3  }
             .sort_by(&:last).reverse.to_h # this sorts the hash by amount: { "home:a" => 3, "home:b" => 1 }
  end
end
