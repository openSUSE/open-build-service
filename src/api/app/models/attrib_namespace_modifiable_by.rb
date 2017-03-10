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
#  attrib_namespace_id :integer          not null
#  user_id             :integer
#  group_id            :integer
#
# Indexes
#
#  attrib_namespace_user_role_all_index                           (attrib_namespace_id,user_id,group_id) UNIQUE
#  bs_group_id                                                    (group_id)
#  bs_user_id                                                     (user_id)
#  index_attrib_namespace_modifiable_bies_on_attrib_namespace_id  (attrib_namespace_id)
#
