class RolesStaticPermission < ApplicationRecord
  belongs_to :role
  belongs_to :static_permission
end

