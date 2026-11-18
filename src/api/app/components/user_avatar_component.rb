class UserAvatarComponent < ApplicationComponent
  attr_reader :avatar_object

  def initialize(avatar_object)
    super()

    @avatar_object = avatar_object
  end

  private

  def short_text
    # Edge case: handle Group avatar objects by linking to the group page
    if avatar_object.is_a?(Group)
      link_to(avatar_object.title, helpers.group_path(avatar_object))
    else
      link_to(avatar_object.login, avatar_object)
    end
  end

  def extended_text
    link_to(helpers.realname_with_login(avatar_object), avatar_object)
  end
end
