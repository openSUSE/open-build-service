class NotificationNotifiableLinkComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
  end

  def call
    return link_to(notifiable_link_text, notifiable_link_path, class: 'mx-1') if notifiable_link_path.present?

    tag.span(notifiable_link_text, class: 'fst-italic mx-1')
  end

  private

  def notifiable_link_text
    @notification.decorator.notifiable_link_text(helpers)
  end

  def notifiable_link_path
    @notification.decorator.notifiable_link_path
  end
end
