class OutdatedRequestNotificationsCollector
  def initialize(scope, notifiable)
    @scope = scope
    @notifiable = notifiable
  end

  def collect
    @scope
      .where(notifiable_type: 'BsRequest')
      .where(notifiable_id: @notifiable.id)
  end
end
