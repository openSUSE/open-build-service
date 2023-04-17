class AvatarAndLinkComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/avatar_and_link_component/default_user_avatar_and_link
  def default_user_avatar_and_link
    render(AvatarAndLinkComponent.new(avatar_object: user))
  end

  # Preview at http://HOST:PORT/rails/view_components/avatar_and_link_component/default_group_avatar_and_link
  def default_group_avatar_and_link
    render(AvatarAndLinkComponent.new(avatar_object: group))
  end

  # Preview at http://HOST:PORT/rails/view_components/avatar_and_link_component/circle_user_avatar_with_short_text_link
  def circle_user_avatar_with_short_text_link
    render(AvatarAndLinkComponent.new(avatar_object: user, shape: :circle))
  end

  # Preview at http://HOST:PORT/rails/view_components/avatar_and_link_component/circle_user_avatar_with_long_text_link
  def circle_user_avatar_with_long_text_link
    render(AvatarAndLinkComponent.new(avatar_object: user, size: 80, shape: :circle, long_link_text: true))
  end

  private

  def user
    User.new(login: 'Iggy', realname: 'Iggy Doe', email: 'id@example.com')
  end

  def group
    Group.new(title: 'group_1', email: 'group_1@example.com')
  end
end
