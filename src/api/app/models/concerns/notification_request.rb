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

    text = [first_bs_request_action.source_project, first_bs_request_action.source_package].compact.join(' / ')
    text << version_suffix(bs_request.source_package_latest_local_version)
    text
  end

  def request_target
    return first_bs_request_action.target_project if size_of_bs_request_actions > 1

    text = [first_bs_request_action.target_project, first_bs_request_action.target_package].compact.join(' / ')
    text << version_suffix(bs_request.target_package_latest_local_version)
    text
  end

  private

  def first_bs_request_action
    @first_bs_request_action ||= bs_request.bs_request_actions.first
  end

  def size_of_bs_request_actions
    @size_of_bs_request_actions ||= bs_request.bs_request_actions.size
  end

  def version_suffix(version)
    return '' unless Flipper.enabled?(:package_version_tracking, User.session) && version.present?

    " (#{version})"
  end
end
