class BsRequestPolicy < ApplicationPolicy
  def create?
    # new request should not have an id (BsRequest#number)
    return false if record.number

    return true if [nil, user.login].include?(record.approver) || user.is_admin?

    false
  end

  def accept?
    is_target_maintainer = record.is_target_maintainer?(user)
    record.state.in?([:new, :review]) && is_target_maintainer
  end

  def revoke?
    is_author = record.is_author?(User.possibly_nobody.login)
    is_author && record.state.in?([:new, :review, :declined])
  end

  def reopen?
    record.state == :declined
  end

  def handle?
    is_target_maintainer = record.is_target_maintainer?(user)
    is_author = record.is_author?(User.possibly_nobody.login)
    record.state.in?([:new, :review, :declined]) && (is_target_maintainer || is_author)
  end

  def decline?
    !record.is_author?(User.possibly_nobody.login)
  end

  def add_reviews?
    my_open_reviews = record.reviews.where(state: 'new').select { |review| review.matches_user?(User.session) }
    is_target_maintainer = record.is_target_maintainer?(user)
    is_author = record.is_author?(User.possibly_nobody.login)
    record.can_add_reviews?(is_author, is_target_maintainer, my_open_reviews)
  end
end
