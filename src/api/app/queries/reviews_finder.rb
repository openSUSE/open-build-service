class ReviewsFinder
  def initialize(relation = Review.all)
    @relation = relation
  end

  def completed_by_reviewer(user)
    @relation.where(
      reviewer: user.login,
      state: [:accepted, :declined]
    )
  end
end
