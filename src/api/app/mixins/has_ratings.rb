# a model that has ratings - e.g. a project and a package
module HasRatings

  def self.included(base)
    base.class_eval do
      has_many :ratings, :as => :db_object, :dependent => :delete_all
    end
  end

  def rating(user_id=nil)
    score = 0
    self.ratings.each do |rating|
      score += rating.score
    end
    count = self.ratings.length
    score = score.to_f
    score /= count
    score = -1 if score.nan?
    score = (score * 100).round.to_f / 100
    if user_rating = self.ratings.find_by_user_id(user_id)
      user_score = user_rating.score
    else
      user_score = 0
    end
    return {:score => score, :count => count, :user_score => user_score}
  end

end
