module NotificationRequest
  extend ActiveSupport::Concern

  # FIXME: Duplicated from RequestHelper, used by WatchedItems
  # Returns strings like "Add Role", "Submit", etc.
  def request_type_of_action
    return 'Multiple Actions' if size_of_bs_request_actions > 1

    first_bs_request_action.type.titleize
  end

  def request_source
    return '' if size_of_bs_request_actions > 1

    [first_bs_request_action.source_project, first_bs_request_action.source_package].compact.join(' / ')
  end

  def request_target
    return first_bs_request_action.target_project if size_of_bs_request_actions > 1

    [first_bs_request_action.target_project, first_bs_request_action.target_package].compact.join(' / ')
  end

  private

  def first_bs_request_action
    @first_bs_request_action ||= bs_request.bs_request_actions.first
  end

  def size_of_bs_request_actions
    @size_of_bs_request_actions ||= bs_request.bs_request_actions.size
  end
end
