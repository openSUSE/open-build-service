class RolesStaticPermission < ActiveRecord::Base
  belongs_to :role
  belongs_to :static_permission
  
  attr_accessible nil
end
