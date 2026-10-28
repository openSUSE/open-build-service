class Vendor < ApplicationRecord
  #### Includes and extends

  #### Constants
  ACCEPTABLE_LOGO_MIME_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_LOGO_SIZE = 5.megabytes

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :project, optional: false
  has_many :distros, dependent: :destroy
  has_one_attached :logo

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :url, length: { maximum: 255 }
  validates :project_id, uniqueness: true
  validate :acceptable_logo_mime_type
  validate :acceptable_logo_size

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  private

  def acceptable_logo_mime_type
    return unless logo.attached?
    return if ACCEPTABLE_LOGO_MIME_TYPES.include?(logo.content_type)

    errors.add(:logo, 'must be a PNG, JPEG, GIF or WebP image')
  end

  def acceptable_logo_size
    return unless logo.attached?
    return unless logo.blob.byte_size > MAX_LOGO_SIZE

    errors.add(:logo, 'is too large (maximum is 5 MB)')
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: vendors
#
#  id          :bigint           not null, primary key
#  description :text(65535)
#  name        :string(255)
#  url         :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  project_id  :integer          not null, uniquely indexed
#
# Indexes
#
#  index_vendors_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
