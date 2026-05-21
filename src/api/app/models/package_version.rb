# Parent model to track the version history of packages locally and upstream
class PackageVersion < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :package, optional: false

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :version, presence: true, length: { maximum: 255 }
  validates :type, presence: true, length: { maximum: 255 }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

# == Schema Information
#
# Table name: package_versions
#
#  id         :bigint           not null, primary key
#  type       :string(255)      not null
#  version    :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  package_id :integer          not null, indexed
#
# Indexes
#
#  index_package_versions_on_package_id  (package_id)
#
# Foreign Keys
#
#  fk_rails_...  (package_id => packages.id)
#
