class AttribNamespaceModifiableBy < ActiveRecord::Base
  belongs_to :attrib_namespaces
  belongs_to :user, :foreign_key => "bs_user_id"
  belongs_to :group, :foreign_key => "bs_group_id"
end

