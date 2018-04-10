# frozen_string_literal: true
class RolesUser < ApplicationRecord
  belongs_to :user
  belongs_to :role
end

# == Schema Information
#
# Table name: roles_users
#
#  user_id    :integer          default(0), not null, indexed => [role_id]
#  role_id    :integer          default(0), not null, indexed, indexed => [user_id]
#  created_at :datetime
#  id         :integer          not null, primary key
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
