class UserDailyContribution
  attr_accessor :user, :date

  def initialize(user, date)
    @user = user
    @date = date
    @date = date.to_date if date.respond_to?(:to_date)
  end

  def call
    { comments: number_of_comments_for_date,
      requests_reviewed: number_of_reviews_done_per_day,
      commits: number_of_commits_done_per_day,
      requests_created: requests_created_for_date }
  end

  private

  def requests_created_for_date
    user.requests_created.where('date(created_at) = ?', date).pluck(:number)
  end

  def number_of_comments_for_date
    user.comments.where('date(created_at) = ?', date).count
  end

  def number_of_reviews_done_per_day
    ReviewsFinder.new.completed_by_reviewer(user)
                 .where('date(reviews.created_at) = ?', date)
                 .joins(:bs_request)
                 .group('bs_requests.number')
                 .order('count_id DESC, bs_requests_number')
                 .count(:id)
  end

  def number_of_commits_done_per_day
    counts = Hash.new(0)
    packages = {}
    user.commit_activities.where('date(date) = ?', date).pluck(:project, :package, :count).each do |e|
      packages[e[0]] ||= []
      packages[e[0]] << [e[1], e[2]]
      counts[e[0]] += e[2]
    end
    counts.sort_by { |_, b| -b }.map { |project, count| [project, packages[project], count] }
  end
end
