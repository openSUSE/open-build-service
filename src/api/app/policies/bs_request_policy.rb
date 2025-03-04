class BsRequestPolicy < ApplicationPolicy
  def create?
    # new request should not have an id (BsRequest#number)
    return false if record.number

    return true if [nil, user.login].include?(record.approver) || user.admin?

    false
  end

  def update_labels?
    user.admin? || record.target_maintainer?(user)
  end

  def handle_request?
    return false if %i[new review declined].exclude?(record.state)

    author? || record.target_maintainer?(user) || record.source_maintainer?(user)
  end

  def add_reviews?
    is_target_maintainer = record.target_maintainer?(user)
    has_open_reviews = record.reviews.where(state: 'new').any? { |review| review.matches_user?(user) }
    record.state.in?(%i[new review]) && (author? || is_target_maintainer || has_open_reviews.present?)
  end

  def revoke_request?
    return false if %i[new review declined].exclude?(record.state)

    author? || record.source_maintainer?(user)
  end

  def report?
    !author?
  end

  def decline_request?
    !(author? || record.source_maintainer?(user))
  end

  def accept_request?
    record.state.in?(%i[new review]) && record.target_maintainer?(user)
  end

  def reopen_request?
    record.state == :declined
  end

  private

  def author?
    record.creator == user.login
  end
end
