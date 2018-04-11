# frozen_string_literal: true

class AttribNamespaceModifiableBy < ApplicationRecord
  belongs_to :attrib_namespaces
  belongs_to :user
  belongs_to :group
end

# == Schema Information
#
# Table name: attrib_namespace_modifiable_bies
#
#  id                  :integer          not null, primary key
#  attrib_namespace_id :integer          not null, indexed => [user_id, group_id]
#  user_id             :integer          indexed => [attrib_namespace_id, group_id], indexed
#  group_id            :integer          indexed => [attrib_namespace_id, user_id], indexed
#
# Indexes
#
#  attrib_namespace_user_role_all_index  (attrib_namespace_id,user_id,group_id) UNIQUE
#  bs_group_id                           (group_id)
#  bs_user_id                            (user_id)
#
# Foreign Keys
#
#  attrib_namespace_modifiable_bies_ibfk_1  (attrib_namespace_id => attrib_namespaces.id)
#  attrib_namespace_modifiable_bies_ibfk_4  (user_id => users.id)
#  attrib_namespace_modifiable_bies_ibfk_5  (group_id => groups.id)
#
