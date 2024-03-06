class NotificationComponent < ApplicationComponent
  NOTIFICATION_ICON = {
    'BsRequest' => 'fa-code-pull-request', 'Comment' => 'fa-comments',
    'Package' => 'fa-xmark text-danger',
    'Report' => 'fa-flag', 'Decision' => 'fa-clipboard-check',
    'Appeal' => 'fa-hand', 'WorkflowRun' => 'fa-book-open'
  }.freeze

  NOTIFICATION_TITLE = {
    'BsRequest' => 'Request notification', 'Comment' => 'Comment notification',
    'Package' => 'Package notification', 'Report' => 'Report notification',
    'Decision' => 'Report decision', 'Appeal' => 'Decision appeal',
    'WorkflowRun' => 'Workflow run'
  }.freeze

  def initialize(notification:, selected_filter:, page:, show_more:, current_user:)
    super

    @notification = notification
    @selected_filter = selected_filter
    @page = page
    @show_more = show_more
    @current_user = current_user
  end

  def notification_icon
    if NOTIFICATION_ICON[@notification.notifiable_type].present?
      tag.i(class: ['fas', NOTIFICATION_ICON[@notification.notifiable_type]], title: NOTIFICATION_TITLE[@notification.notifiable_type])
    else
      tag.i(class: %w[fas fa-user-tag], title: 'Relationship notification')
    end
  end
end
