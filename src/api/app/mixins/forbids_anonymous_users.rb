module ForbidsAnonymousUsers
  class AnonymousUser < APIException
    setup 401
  end

  #
  # The following depends on ApplicationController:check_for_anonymous_user
  # conditionally loading the anonymous user!
  #
  def require_login
    # we may allow anonymous GET operations (if configured) but we require
    # a valid account on other opertations
    be_not_nobody! unless request.get?
  end

  def be_not_nobody!
    if !User.current || User.current.is_nobody?
      raise AnonymousUser.new 'Anonymous user is not allowed here - please login'
    end
  end
end
