class WorkflowRunRequestActionFilterComponent < ApplicationComponent
  def initialize(filter_item:, selected_filter:)
    super

    @filter_options = ['all'] + SCMWebhook::ALLOWED_PULL_REQUEST_ACTIONS + SCMWebhook::ALLOWED_MERGE_REQUEST_ACTIONS
    @filter_item = filter_item
    @selected_value = selected_filter
  end
end
