# frozen_string_literal: true

class RolesStaticPermission < ApplicationRecord
  belongs_to :role
  belongs_to :static_permission
end

# == Schema Information
#
# Table name: roles_static_permissions
#
#  role_id              :integer          default(0), not null, indexed, indexed => [static_permission_id]
#  static_permission_id :integer          default(0), not null, indexed => [role_id]
#
# Indexes
#
#  role_id                             (role_id)
#  roles_static_permissions_all_index  (static_permission_id,role_id) UNIQUE
#
# Foreign Keys
#
#  roles_static_permissions_ibfk_1  (role_id => roles.id)
#  roles_static_permissions_ibfk_2  (static_permission_id => static_permissions.id)
#
