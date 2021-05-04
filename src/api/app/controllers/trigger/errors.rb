module Trigger::Errors
  extend ActiveSupport::Concern

  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end

  class BadScmHeaders < APIError
    setup 'bad_request',
          400,
          'Valid SCM HTTP request headers required'
  end
end
