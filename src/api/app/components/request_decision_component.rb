class RequestDecisionComponent < ApplicationComponent
  def initialize(bs_request:, action:, is_target_maintainer:, package_maintainers:, show_project_maintainer_hint:)
    super

    @bs_request = bs_request
    @is_target_maintainer = is_target_maintainer
    @action = action
    @package_maintainers = package_maintainers
    @creator = bs_request.creator
    @forward_allowed = forward_allowed?

    return unless render? && show_project_maintainer_hint

    @package_maintainers_hint = "Note\n" \
                                'You are a project maintainer but not a package maintainer. This package ' \
                                "has #{pluralize(@package_maintainers.size, 'package maintainer')} assigned. Please keep " \
                                'in mind that also package maintainers would like to review this request.'.freeze
  end

  def render?
    policy(@bs_request).handle_request?
  end

  def single_action_request
    @single_action_request ||= @bs_request.bs_request_actions.count == 1
  end

  def confirmation
    if @bs_request.state == :review
      { confirm: "Do you really want to approve this request, despite of open review requests?\n\n#{@package_maintainers_hint}" }
    else
      {}
    end
  end

  def other_decision_confirmation(decision_text)
    { confirm: "Do you really want to #{decision_text} this request?\n\n#{@package_maintainers_hint}" }
  end

  def show_add_submitter_as_maintainer_option?
    @action.type == 'submit' && !@action.creator_is_target_maintainer
  end

  def accept_with_options_allowed?
    single_action_request && @is_target_maintainer && @bs_request.state.in?(%i[new review])
  end

  def forward_allowed?
    @action.type == 'submit' && policy(@bs_request).accept_request? && @action.forward.any?
  end

  def make_maintainer_of
    @action.target_project + ("/#{@action.target_package}" if @action.target_package)
  end
end
