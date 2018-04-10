# frozen_string_literal: true
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
#  attrib_type_id :integer          not null, indexed => [user_id, group_id, role_id]
#  user_id        :integer          indexed => [attrib_type_id, group_id, role_id], indexed
#  group_id       :integer          indexed => [attrib_type_id, user_id, role_id], indexed
#  role_id        :integer          indexed => [attrib_type_id, user_id, group_id], indexed
#
# Indexes
#
#  attrib_type_user_role_all_index  (attrib_type_id,user_id,group_id,role_id) UNIQUE
#  group_id                         (group_id)
#  role_id                          (role_id)
#  user_id                          (user_id)
#
# Foreign Keys
#
#  attrib_type_modifiable_bies_ibfk_1  (user_id => users.id)
#  attrib_type_modifiable_bies_ibfk_2  (group_id => groups.id)
#  attrib_type_modifiable_bies_ibfk_3  (role_id => roles.id)
#
