class BsRequestPolicy < ApplicationPolicy
  def create?
    # new request should not have an id (BsRequest#number)
    return false if record.number

    return true if [nil, user.login].include?(record.approver) || user.is_admin?

    false
  end

  def handle_request?
    record.state.in?([:new, :review, :declined]) && (target_maintainer? || author?)
  end

  def can_add_reviews?
    open_reviews = record.reviews.where(state: 'new').select { |review| review.matches_user?(user) }
    record.state.in?([:new, :review]) && (author? || target_maintainer? || open_reviews.present?)
  end

  def can_revoke_request?
    author? && record.state.in?([:new, :review, :declined])
  end

  def can_decline_request?
    !author?
  end

  def target_maintainer?
    record.bs_request_actions.all? { |action| action.is_target_maintainer?(user) }
  end

  private

  def author?
    record.creator == user.login
  end
end
