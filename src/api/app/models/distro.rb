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
  validates :vendor_id, uniqueness: true

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
#  name        :string(255)
#  url         :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  vendor_id   :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_distros_on_vendor_id  (vendor_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (vendor_id => vendors.id)
#
