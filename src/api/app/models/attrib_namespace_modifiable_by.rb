class AttribNamespaceModifiableBy < ActiveRecord::Base
  belongs_to :attrib_namespaces
  belongs_to :user
  belongs_to :group
end

