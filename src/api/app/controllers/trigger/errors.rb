module Trigger::Errors
  class NotEnabledToken < APIError
    setup 'not_enabled_token', 403, 'This token is not enabled.'
  end

  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end

  class MissingExtractor < APIError
    setup 'bad_request', 400, 'Extractor could not be created.'
  end
end
