module Trigger::Errors
  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end

  class MissingExtractor < APIError
    setup 'bad_request', 400, 'Extractor could not be created.'
  end
end
