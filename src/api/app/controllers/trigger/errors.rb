module Trigger::Errors
  extend ActiveSupport::Concern

  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end
end
