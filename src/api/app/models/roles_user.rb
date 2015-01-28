class RolesUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :role

  self.primary_key = 'roles_users_all_index'
end
