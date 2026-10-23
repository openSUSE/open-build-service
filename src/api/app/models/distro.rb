class Distro < ApplicationRecord
  #### Includes and extends

  #### Constants
  ACCEPTABLE_LOGO_MIME_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_LOGO_SIZE = 5.megabytes
  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :vendor, optional: false
  has_many :distro_releases, dependent: :destroy
  has_one :project, through: :vendor
  has_one_attached :logo
  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :url, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :vendor_id }
  validate :acceptable_logo
  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  private

  def acceptable_logo
    return unless logo.attached?

    unless ACCEPTABLE_LOGO_MIME_TYPES.include?(logo.content_type)
      errors.add(:logo, 'must be a PNG, JPEG, GIF or WebP image')
    end

    return unless logo.blob.byte_size > MAX_LOGO_SIZE

    errors.add(:logo, 'is too large (maximum is 5 MB)')
  end

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
