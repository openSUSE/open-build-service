class UserAvatarComponent < ApplicationComponent
  attr_reader :avatar_object

  def initialize(avatar_object)
    super

    @avatar_object = avatar_object
  end

  private

  def short_text
    link_to(avatar_object.login, avatar_object)
  end

  def extended_text
    link_to(helpers.realname_with_login(avatar_object), avatar_object)
  end
end
