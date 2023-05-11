class BsRequestPolicy < ApplicationPolicy
  def create?
    # new request should not have an id (BsRequest#number)
    return false if record.number

    return true if [nil, user.login].include?(record.approver) || user.is_admin?

    false
  end

  def handle_request?
    is_target_maintainer = record.is_target_maintainer?(user)
    record.state.in?([:new, :review, :declined]) && (is_target_maintainer || author?)
  end

  def can_add_reviews?
    is_target_maintainer = record.is_target_maintainer?(user)
    open_reviews = record.reviews.where(state: 'new').select { |review| review.matches_user?(user) }
    record.state.in?([:new, :review]) && (author? || is_target_maintainer || open_reviews.present?)
  end

  def can_revoke_request?
    author? && record.state.in?([:new, :review, :declined])
  end

  private

  def author?
    record.creator == user.login
  end
end
