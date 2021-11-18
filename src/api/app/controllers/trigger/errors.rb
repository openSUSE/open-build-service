module Trigger::Errors
  extend ActiveSupport::Concern

  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end

  class BadScmPayload < APIError
    setup 'bad_request',
          400,
          'Failed to parse the JSON payload of your request'
  end
end
