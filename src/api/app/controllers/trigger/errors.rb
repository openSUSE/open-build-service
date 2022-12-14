module Trigger::Errors
  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end

  class BadSCMPayload < APIError
    setup 'bad_request',
          400,
          'Failed to parse the JSON payload of your request'
  end
end
