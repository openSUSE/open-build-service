class RolesUser < ApplicationRecord
  belongs_to :user
  belongs_to :role
end

# == Schema Information
#
# Table name: roles_users
#
#  id         :integer          not null, primary key
#  created_at :datetime
#  role_id    :integer          default(0), not null, indexed, indexed => [user_id]
#  user_id    :integer          default(0), not null, indexed => [role_id]
#
# Indexes
#
#  role_id                (role_id)
#  roles_users_all_index  (user_id,role_id) UNIQUE
#
# Foreign Keys
#
#  roles_users_ibfk_1  (user_id => users.id)
#  roles_users_ibfk_2  (role_id => roles.id)
#
