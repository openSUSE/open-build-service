class AvatarComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/avatar_component/default_user_avatar
  # No shape, standard size
  def default_user_avatar
    render(AvatarComponent.new(name: user.name, email: user.email))
  end

  # Preview at http://HOST:PORT/rails/view_components/avatar_component/circle_user_avatar
  def circle_user_avatar
    render(AvatarComponent.new(name: user.name, email: user.email, shape: :circle))
  end

  # Preview at http://HOST:PORT/rails/view_components/avatar_component/big_circle_group_avatar
  def big_circle_group_avatar
    render(AvatarComponent.new(name: group.name, email: group.email, size: 80, shape: :circle))
  end

  private

  def user
    User.new(login: 'Iggy', realname: 'Iggy Doe', email: 'id@example.com')
  end

  def group
    Group.new(title: 'group_1', email: 'group_1@example.com')
  end
end
