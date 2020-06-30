class OutdatedNotificationsFinder::BsRequest
  def initialize(scope, notifiable)
    @scope = scope
    @notifiable = notifiable
  end

  def call
    @scope.where(notifiable_type: 'BsRequest', notifiable_id: @notifiable.id)
  end
end
