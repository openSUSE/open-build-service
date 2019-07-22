# typed: strict
module Trigger::Errors
  extend ActiveSupport::Concern

  class NoPermissionForInactive < APIError
    setup 403, 'no permission due to inactive user'
  end

  class TokenNotFound < APIError
    setup 404, 'Token not found'
  end

  class InvalidToken < APIError
    setup 'permission_denied',
          403,
          'No valid token found "Authorization" header'
  end

  class NoPermissionForPackage < APIError
  end

  class NoRepositoryCouldBeReleased < APIError
  end

  class NoPermissionForTarget < APIError
  end
end
