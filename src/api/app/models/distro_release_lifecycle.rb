class DistroReleaseLifecycle < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
  # validate: true so an unknown status coming from the form fails validation instead of raising ArgumentError
  enum :status, {
    planned: 0,
    active: 1,
    ended: 2
  }, validate: true

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :distro_release, optional: false

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :distro_release_id }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def to_param
    name
  end

  def status_class
    case status
    when 'active'
      'text-bg-primary'
    when 'ended'
      'text-bg-danger'
    else
      'text-bg-secondary'
    end
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: distro_release_lifecycles
#
#  id                :bigint           not null, primary key
#  date              :date
#  name              :string(255)      uniquely indexed => [distro_release_id]
#  status            :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  distro_release_id :bigint           not null, uniquely indexed => [name]
#
# Indexes
#
#  index_distro_release_lifecycles_on_distro_release_id_and_name  (distro_release_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (distro_release_id => distro_releases.id)
#
