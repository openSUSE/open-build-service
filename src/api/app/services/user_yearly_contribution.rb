class UserYearlyContribution
  attr_reader :first_day, :user

  def initialize(user, first_day)
    @user = user
    @first_day = first_day
    @first_day = first_day.to_date if first_day.respond_to?(:to_date)
  end

  def call
    merge_hashes([requests_created, comments, reviews_done, commits_done])
  end

  private

  def requests_created
    user.requests_created.where('created_at > ?', first_day).group('date(created_at)').count
  end

  def comments
    user.comments.where('created_at > ?', first_day).group('date(created_at)').count
  end

  def reviews_done
    # User.reviews are by_user, we want also by_package and by_group reviews accepted/declined
    ReviewsFinder.new.completed_by_reviewer(user)
                 .where('created_at > ?', first_day)
                 .group('date(created_at)')
                 .count
  end

  def commits_done
    user.commit_activities.group(:date).where('date > ?', first_day).sum(:count)
  end

  def merge_hashes(hashes_array)
    hashes_array.inject { |h1, h2| h1.merge(h2) { |_, value1, value2| value1 + value2 } }
  end
end
