class RequestDecisionComponent < ApplicationComponent
  def initialize(bs_request:, action:, is_target_maintainer:, is_author:)
    super

    @bs_request = bs_request
    @is_target_maintainer = is_target_maintainer
    @action = action
    @is_author = is_author
  end

  def render?
    can_handle_request?
  end

  def single_action_request
    @single_action_request ||= @bs_request.bs_request_actions.count == 1
  end

  def confirmation
    if @bs_request.state == :review
      { confirm: 'Do you really want to approve this request, despite of open review requests?' }
    else
      {}
    end
  end

  def show_add_submitter_as_maintainer_option?
    !@action[:creator_is_target_maintainer] && @action[:type] == :submit
  end

  # TODO: Move all those "can_*" checks to a pundit policy
  def can_handle_request?
    @bs_request.state.in?([:new, :review, :declined]) && (@is_target_maintainer || @is_author)
  end

  def can_revoke_request?
    @is_author && @bs_request.state.in?([:new, :review, :declined])
  end

  def can_accept_request?
    @bs_request.state.in?([:new, :review]) && @is_target_maintainer
  end

  def can_decline_request?
    !@is_author
  end

  def can_reopen_request?
    @bs_request.state == :declined
  end
end
