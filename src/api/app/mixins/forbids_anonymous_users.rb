module ForbidsAnonymousUsers
  class AnonymousUser < APIException
    setup 401
  end

  def be_not_nobody!
    if !User.current || User.current.is_nobody?
      raise AnonymousUser.new 'Anonymous user is not allowed here - please login'
    end
  end
end
