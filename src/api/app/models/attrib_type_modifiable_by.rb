class AttribTypeModifiableBy < ApplicationRecord
  belongs_to :attrib_type
  belongs_to :user
  belongs_to :group
  belongs_to :role
end
