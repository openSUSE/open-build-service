class AttribNamespaceModifiableBy < ApplicationRecord
  belongs_to :attrib_namespaces
  belongs_to :user
  belongs_to :group
end

