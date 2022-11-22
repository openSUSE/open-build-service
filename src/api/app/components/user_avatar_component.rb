class UserAvatarComponent < ApplicationComponent
  def initialize(user)
    super

    @user = user
  end

  private

  def avatar_object
    @avatar_object ||= User.find_by_login(@user)
  end

  def short_text
    link_to(avatar_object.login, avatar_object)
  end

  def extended_text
    link_to(helpers.realname_with_login(avatar_object), avatar_object)
  end
end
