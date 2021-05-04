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
          'Could not find the required HTTP request headers X-GitHub-Event or X-Gitlab-Event'
  end

  class BadScmPayload < APIError
    setup 'bad_request',
          400,
          'Failed to parse the JSON payload of your request'
  end
end
