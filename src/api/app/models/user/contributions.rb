class User::Contributions
  attr_accessor :user, :first_day, :date

  def initialize(user)
    @user = user
  end

  def activity_hash(first_day)
    @first_day = first_day
    merge_hashes([requests_created, comments, reviews_done, commits_done])
  end

  def activities_per_date(date)
    @date = date
    { comments: comments_for_date,
      requests_reviewed: reviews_done_per_day,
      commits: commits_done_per_day,
      requests_created: requests_created_for_date }
  end

  private

  def requests_created_for_date
    user.requests_created.where('date(created_at) = ?', date).pluck(:number)
  end

  def requests_created
    user.requests_created.where('created_at > ?', first_day).group('date(created_at)').count
  end

  def comments_for_date
    user.comments.where('date(created_at) = ?', date).count
  end

  def comments
    user.comments.where('created_at > ?', first_day).group('date(created_at)').count
  end

  def reviews_done
    # User.reviews are by_user, we want also by_package and by_group reviews accepted/declined
    Review.where(reviewer: user.login, state: [:accepted, :declined]).where('created_at > ?', first_day).group('date(created_at)').count
  end

  def reviews_done_per_day
    Review.where(reviewer: user.login, state: [:accepted, :declined])
          .where('date(reviews.created_at) = ?', date)
          .joins(:bs_request)
          .group('bs_requests.number')
          .order('count_id DESC, bs_requests_number')
          .count(:id)
  end

  def commits_done
    user.commit_activities.group(:date).where('date > ?', first_day).sum(:count)
  end

  def commits_done_per_day
    counts = Hash.new(0)
    packages = {}
    user.commit_activities.where(date: date).pluck(:project, :package, :count).each do |e|
      packages[e[0]] ||= []
      packages[e[0]] << [e[1], e[2]]
      counts[e[0]] += e[2]
    end
    counts.sort_by { |_, b| -b }.map { |project, count| [project, packages[project], count] }
  end

  def merge_hashes(hashes_array)
    hashes_array.inject { |h1, h2| h1.merge(h2) { |_, value1, value2| value1 + value2 } }
  end
end
