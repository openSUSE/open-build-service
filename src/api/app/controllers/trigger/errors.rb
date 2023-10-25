module Trigger::Errors
  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found'
  end

  class MissingExtractor < APIError
    setup 'bad_request', 400, 'Extractor could not be created.'
  end

  class BadSCMPayload < APIError
    setup 'bad_request',
          400,
          'Failed to parse the JSON payload of your request'
  end

  class MissingPackage < APIError
    setup 'bad_request', 400, 'A package must be provided for the operations rebuild, release and runservice'
  end
end
