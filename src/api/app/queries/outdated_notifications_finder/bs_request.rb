# This class looks for a request with the request number in the event payload and return that request's notifications.
class OutdatedNotificationsFinder::BsRequest
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
    @request_number = @parameters.dig(:event_payload, 'number')
  end

  def call
    return [] unless @request_number

    bs_request = BsRequest.find_by(number: @request_number)
    @scope.where(notifiable_type: 'BsRequest', notifiable_id: bs_request.id)
  end
end
