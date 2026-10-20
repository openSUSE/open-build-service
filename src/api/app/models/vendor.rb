class Vendor < ApplicationRecord
  #### Includes and extends

  #### Constants
  ALLOWED_LOGO_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_LOGO_SIZE = 2.megabytes

  #### Self config
  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :project, optional: false
  has_many :distros, dependent: :destroy

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :url, length: { maximum: 255 }
  validates :project_id, uniqueness: true
  validate :acceptable_logo
  validates :logo_content_type, length: { maximum: 100 }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def logo=(file)
    # Duck-type to check if it is an IO/file object (e.g., UploadedFile, File)
    if file.respond_to?(:read)
      self.logo_content_type = file.content_type.to_s.strip
      super(file.read)
    else
      super
    end
  end

  def logo_data_uri
    logo_to_render = errors[:logo].present? ? attribute_in_database(:logo) : logo
    content_type_to_render = errors[:logo].present? ? attribute_in_database(:logo_content_type) : logo_content_type

    return if logo_to_render.blank?

    "data:#{content_type_to_render};base64,#{Base64.strict_encode64(logo_to_render)}"
  end

  private

  def acceptable_logo
    return if logo.blank?

    unless ALLOWED_LOGO_TYPES.include?(logo_content_type) && valid_logo_magic_number?
      errors.add(:logo, 'must be a valid image (JPEG, PNG, or WEBP)')
    end

    errors.add(:logo, "size cannot exceed #{MAX_LOGO_SIZE / 1.megabyte} MB") if logo.bytesize > MAX_LOGO_SIZE
  end

  def valid_logo_magic_number?
    return false if logo.blank?

    binary = logo.b
    case logo_content_type
    when 'image/png'  then binary.start_with?("\x89PNG\r\n\x1a\n".b)
    when 'image/jpeg' then binary.start_with?("\xFF\xD8\xFF".b)
    when 'image/webp' then binary.start_with?('RIFF'.b) && binary[8..11] == 'WEBP'.b
    else false
    end
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: vendors
#
#  id                :bigint           not null, primary key
#  description       :text(65535)
#  logo              :binary(16777215)
#  logo_content_type :string(100)
#  name              :string(255)
#  url               :string(255)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :integer          not null, uniquely indexed
#
# Indexes
#
#  index_vendors_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
