class WorkflowRunRequestActionFilterComponent < ApplicationComponent
  def initialize(filter_item:)
    super

    @filter_options = ['all'] + SCMWebhook::ALLOWED_PULL_REQUEST_ACTIONS + SCMWebhook::ALLOWED_MERGE_REQUEST_ACTIONS
    @filter_item = filter_item
  end
end
