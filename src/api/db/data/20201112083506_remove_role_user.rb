class RemoveRoleUser < ActiveRecord::Migration[6.0]
  def up
    Role.destroy_by(title: 'User')
  end

  def down
    # While we can recreate the role, we cannot recreate associations between users and the role "User" (so records in RolesUser)
    Role.create(title: 'User', global: true)
  end
end
