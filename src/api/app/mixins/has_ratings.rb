# a model that has ratings - e.g. a project and a package
module HasRatings
  def self.included(base)
    base.class_eval do
      has_many :ratings, as: :db_object, dependent: :delete_all
    end
  end

  def rating(user_id = nil)
    score = 0
    ratings.each do |rating|
      score += rating.score
    end
    count = ratings.length
    score = score.to_f
    score /= (count.nonzero? || 1)
    score = -1 if score.nan?
    score = (score * 100).round.to_f / 100
    user_rating = ratings.find_by_user_id(user_id)
    if user_rating
      user_score = user_rating.score
    else
      user_score = 0
    end
    {score: score, count: count, user_score: user_score}
  end
end
