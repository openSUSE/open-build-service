class ReviewsFinder
  def initialize(relation = Review.all)
    @relation = relation
  end

  def completed_by_reviewer(user)
    @relation.where(
      reviewer: user.login,
      state: %i[accepted declined]
    )
  end

  def open_reviews_for_user(user)
    @relation.where(state: 'new').select { |review| review.matches_user?(user) }
  end
end
