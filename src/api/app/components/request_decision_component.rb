class RequestDecisionComponent < ApplicationComponent
  attr_reader :action, :bs_request, :can_accept_request, :can_decline_request, :can_handle_request, :can_reopen_request, :can_revoke_request, :request_creator, :request_number

  def initialize(bs_request:, action:, can_accept_request:, can_revoke_request:, can_reopen_request:, can_handle_request:, can_decline_request:)
    super

    @bs_request = bs_request
    @action = action
    @request_number = bs_request.number
    @request_creator = bs_request.creator

    @can_accept_request = can_accept_request
    @can_revoke_request = can_revoke_request
    @can_reopen_request = can_reopen_request
    @can_handle_request = can_handle_request
    @can_decline_request = can_decline_request
  end

  def render?
    can_handle_request
  end

  def single_action_request
    bs_request.bs_request_actions.count == 1
  end

  def confirmation
    if bs_request.state == :review
      { confirm: 'Do you really want to approve this request, despite of open review requests?' }
    else
      {}
    end
  end

  def show_add_submitter_as_maintainer_option?
    !action[:creator_is_target_maintainer] && action[:type] == :submit
  end
end
