class RolesUser < ApplicationRecord
  belongs_to :user
  belongs_to :role
end

# == Schema Information
#
# Table name: roles_users
#
#  user_id    :integer          default("0"), not null
#  role_id    :integer          default("0"), not null
#  created_at :datetime
#  id         :integer          not null, primary key
#
# Indexes
#
#  role_id                (role_id)
#  roles_users_all_index  (user_id,role_id) UNIQUE
#
