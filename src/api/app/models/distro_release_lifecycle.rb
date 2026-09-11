class DistroReleaseLifecycle < ApplicationRecord
  #### Includes and extends

  #### Constants
  STATUS_LABELS = {
    'release_candidate' => 'Release Candidate',
    'general_availability' => 'General Availability',
    'extended_support' => 'Extended Support',
    'end_of_life' => 'End of Life'
  }.freeze

  #### Self config

  #### Attributes
  enum :status, {
    planned: 0,
    development: 1,
    alpha: 2,
    beta: 3,
    release_candidate: 4,
    general_availability: 5,
    maintenance: 6,
    extended_support: 7,
    deprecated: 8,
    end_of_life: 9
  }, validate: true

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :distro_release, optional: false

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)
  scope :chronological, -> { order(Arel.sql('date IS NULL'), :date) }

  #### Validations macros
  validates :name, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :distro_release_id }
  validates :name, :date, presence: true

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  def status_label
    STATUS_LABELS.fetch(status, status.humanize)
  end

  def status_class
    case status
    when 'general_availability'
      'text-bg-success'
    when 'maintenance', 'extended_support'
      'text-bg-primary'
    when 'development', 'alpha', 'beta', 'release_candidate'
      'text-bg-info'
    when 'deprecated'
      'text-bg-warning'
    when 'end_of_life'
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
#  date              :date             not null
#  name              :string(255)      not null, uniquely indexed => [distro_release_id]
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
