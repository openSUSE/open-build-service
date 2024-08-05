class BsRequestPolicy < ApplicationPolicy
  def create?
    # new request should not have an id (BsRequest#number)
    return false if record.number

    return true if [nil, user.login].include?(record.approver) || user.is_admin?

    false
  end

  def update_labels?
    user.is_admin? || record.is_target_maintainer?(user)
  end

  def handle_request?
    return false if %i[new review declined].exclude?(record.state)

    author? || record.is_target_maintainer?(user) || record.is_source_maintainer?(user)
  end

  def add_reviews?
    is_target_maintainer = record.is_target_maintainer?(user)
    has_open_reviews = record.reviews.where(state: 'new').any? { |review| review.matches_user?(user) }
    record.state.in?(%i[new review]) && (author? || is_target_maintainer || has_open_reviews.present?)
  end

  def revoke_request?
    return false if %i[new review declined].exclude?(record.state)

    author? || record.is_source_maintainer?(user)
  end

  def report?
    !author?
  end

  def decline_request?
    !author?
  end

  private

  def author?
    record.creator == user.login
  end
end
