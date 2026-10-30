class DistroReleaseRepositoryArchitecture < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :distro_release, optional: false
  belongs_to :repository_architecture, optional: false

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :repository_architecture_id, uniqueness: { scope: :distro_release_id }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

# == Schema Information
#
# Table name: distro_release_repository_architectures
#
#  id                         :bigint           not null, primary key
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  distro_release_id          :bigint           not null, uniquely indexed => [repository_architecture_id]
#  repository_architecture_id :integer          not null, indexed, uniquely indexed => [distro_release_id]
#
# Indexes
#
#  fk_rails_ecfa08540b                                             (repository_architecture_id)
#  idx_on_distro_release_id_repository_architecture_id_0ae46a8884  (distro_release_id,repository_architecture_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (distro_release_id => distro_releases.id)
#  fk_rails_...  (repository_architecture_id => repository_architectures.id)
#
