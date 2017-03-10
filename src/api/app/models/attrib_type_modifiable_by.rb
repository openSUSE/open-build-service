class AttribTypeModifiableBy < ApplicationRecord
  belongs_to :attrib_type
  belongs_to :user
  belongs_to :group
  belongs_to :role
end

# == Schema Information
#
# Table name: attrib_type_modifiable_bies
#
#  id             :integer          not null, primary key
#  attrib_type_id :integer          not null
#  user_id        :integer
#  group_id       :integer
#  role_id        :integer
#
# Indexes
#
#  attrib_type_user_role_all_index  (attrib_type_id,user_id,group_id,role_id) UNIQUE
#  group_id                         (group_id)
#  role_id                          (role_id)
#  user_id                          (user_id)
#
