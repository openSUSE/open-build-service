class OutdatedNotificationsFinder::User
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
  end

  # Notifications about the same role are overwritten, independently of the action
  def call
    @scope.where(notifiable_type: 'User', notifiable_id: @parameters[:notifiable_id])
      .where("JSON_UNQUOTE(JSON_EXTRACT(event_payload, '$.role')) = ?", @parameters.dig(:event_payload, 'role'))
  end
end
