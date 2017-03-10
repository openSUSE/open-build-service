class RolesStaticPermission < ApplicationRecord
  belongs_to :role
  belongs_to :static_permission
end

# == Schema Information
#
# Table name: roles_static_permissions
#
#  role_id              :integer          default("0"), not null
#  static_permission_id :integer          default("0"), not null
#
# Indexes
#
#  role_id                             (role_id)
#  roles_static_permissions_all_index  (static_permission_id,role_id) UNIQUE
#
