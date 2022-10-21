class NotificationComponent < ApplicationComponent
  def initialize(notification:, selected_filter:)
    super

    @notification = notification
    @selected_filter = selected_filter
  end

  def notification_icon
    case @notification.notifiable_type
    when 'BsRequest'
      tag.i(class: ['fas', 'fa-code-pull-request'], title: 'Comment notification')
    when 'Comment'
      tag.i(class: ['fas', 'fa-comments'], title: 'Comment notification')
    else
      tag.i(class: ['fas', 'fa-user-tag'], title: 'Relationship notification')
    end
  end
end
