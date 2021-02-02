class ProjectFilterChoicesPresenter
  attr_reader :choices, :selected

  def initialize(selected)
    @choices = projects_for_filter
    @selected = selected
  end

  private

  # Returns a hash where the key is the name of the project and the value is the amount of notifications
  # associated to that project. The hash is sorted by amount and then name.
  def projects_for_filter
    Project.joins(:notifications)
           .where(notifications: { subscriber: User.session, delivered: false, web: true })
           .order('name desc').group(:name).count # this query returns a sorted-by-name hash like { "home:b" => 1, "home:a" => 3  }
           .sort_by(&:last).reverse.to_h # this sorts the hash by amount: { "home:a" => 3, "home:b" => 1 }
  end
end
