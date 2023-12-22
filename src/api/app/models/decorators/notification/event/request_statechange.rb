class Decorators::Notification::Event::RequestStatechange < Decorators::Notification::Common
  def description_text
    bs_request = notification.notifiable
    BsRequestActionSourceAndTargetComponent.new(bs_request).call
  end
end
