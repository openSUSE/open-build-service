class RequestDecisionComponent < ApplicationComponent
  def initialize(bs_request:, package_maintainers:, show_project_maintainer_hint:)
    super

    @bs_request = bs_request
    @package_maintainers = package_maintainers

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
      { confirm: "Accept this request, despite the open reviews?\n\n#{@package_maintainers_hint}" }
    else
      { confirm: 'Accept this request? This will commit the changes to the target!' }
    end
  end

  def show_add_creator_as_maintainer?
    return false unless submit_actions.any?

    submit_actions.none?(&:creator_is_target_maintainer)
  end

  def show_forward?
    forwards.any?
  end

  def forwards_names
    names = forwards.first(2).map { |f| f.first.values.take(2).join('/') }
    names.push("#{forwards.length} more") if forwards.length > 4
    names.to_sentence
  end

  def target_names
    names = submit_actions.first(2).map(&:uniq_key)
    names.push("#{forwards.length} more") if submit_actions.length > 4
    names.to_sentence
  end

  private

  def submit_actions
    @bs_request.bs_request_actions.where(type: :submit)
  end

  def forwards
    return [] unless submit_actions.any?
    return [] unless submit_actions.any? { |submit_action| submit_action.forward.any? }

    submit_actions.filter_map { |submit_action| submit_action.forward if submit_action.forward.any? }
  end
end
