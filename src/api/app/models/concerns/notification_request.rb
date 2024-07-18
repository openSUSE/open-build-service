module NotificationRequest
  extend ActiveSupport::Concern

  # FIXME: Duplicated from RequestHelper, used by WatchedItems
  # Returns strings like "Add Role", "Submit", etc.
  def request_type_of_action
    return 'Multiple Actions' if bs_request.bs_request_actions.size > 1

    bs_request.bs_request_actions.first.type.titleize
  end

  def request_source
    first_bs_request_action = bs_request.bs_request_actions.first

    return '' if bs_request.bs_request_actions.size > 1

    [first_bs_request_action.source_project, first_bs_request_action.source_package].compact.join(' / ')
  end

  def request_target
    first_bs_request_action = bs_request.bs_request_actions.first

    return first_bs_request_action.target_project if bs_request.bs_request_actions.size > 1

    [first_bs_request_action.target_project, first_bs_request_action.target_package].compact.join(' / ')
  end
end
