class DistroRelease < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :distro, optional: false
  has_many :distro_release_repository_architectures, dependent: :destroy
  has_many :repository_architectures, through: :distro_release_repository_architectures
  has_many :repositories, through: :repository_architectures
  has_many :projects, through: :repositories

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :url, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :distro_id }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

# == Schema Information
#
# Table name: distro_releases
#
#  id          :bigint           not null, primary key
#  description :text(65535)
#  name        :string(255)      uniquely indexed => [distro_id]
#  url         :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  distro_id   :bigint           not null, uniquely indexed => [name]
#
# Indexes
#
#  index_distro_releases_on_distro_id_and_name  (distro_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (distro_id => distros.id)
#
