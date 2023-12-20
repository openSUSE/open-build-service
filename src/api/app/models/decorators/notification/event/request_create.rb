class Decorators::Notification::Event::RequestCreate < Decorators::Notification::Common
  def description_text
    bs_request = notification.notifiable
    BsRequestActionSourceAndTargetComponent.new(bs_request).call
  end

  def notifiable_link_text(helpers)
    "#{helpers.request_type_of_action(notification.notifiable)} Request ##{notification.notifiable.number}"
  end
end
