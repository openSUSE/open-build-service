class OutdatedNotifications::BsRequest
  def initialize(scope, notifiable)
    @scope = scope
    @notifiable = notifiable
  end

  def call
    @scope
      .where(notifiable_type: 'BsRequest')
      .where(notifiable_id: @notifiable.id)
  end
end
