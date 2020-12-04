class UserAdminRights
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def toggle!
    raise NotFoundError unless user

    if user.roles.exists?(title: 'Admin')
      RolesUser.where(user: user, role: admin_role).first.destroy
    else
      user.roles << admin_role
    end

    user
  end

  private

  def admin_role
    Role.global.where(title: 'Admin').first
  end
end
