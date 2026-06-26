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

  def decline_request?
    return false if BsRequest::FINAL_REQUEST_STATES.include?(record.state)

    !(author? || record.source_maintainer?(user))
  end

  def accept_request?
    record.state.in?(%i[new review]) && record.target_maintainer?(user)
  end

  def reopen_request?
    record.state == :declined
  end

  def forward_request?
    # A user who has permission to accept a bs_request has a maintainer role on all targets
    # of the associated bs_request_actions
    return false unless accept_request?

    # Only bs_request_actions of type submit can be forwarded
    record.bs_request_actions.where(type: :submit).any? { |submit_action| submit_action.forward.any? }
  end

  def add_creator_as_maintainer?
    # A user who has permission to accept a bs_request has a maintainer role on all targets
    # of the associated bs_request_actions
    return false unless accept_request?

    record.bs_request_actions.where(type: :submit).any? { |submit_action| !submit_action.creator_is_target_maintainer? }
  end

  private

  def author?
    record.creator == user.login
  end
end
