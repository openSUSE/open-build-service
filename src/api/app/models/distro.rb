class Distro < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :vendor, optional: false

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :url, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :vendor_id }
  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

# == Schema Information
#
# Table name: distros
#
#  id          :bigint           not null, primary key
#  description :text(65535)
#  name        :string(255)      uniquely indexed => [vendor_id]
#  url         :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  vendor_id   :bigint           not null, uniquely indexed => [name]
#
# Indexes
#
#  index_distros_on_vendor_id_and_name  (vendor_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (vendor_id => vendors.id)
#
