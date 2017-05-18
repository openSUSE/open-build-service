# TODO: Please overwrite this comment with something explaining the model target
class Kiwi::Repository < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :image

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :source_path, presence: true
  validate :source_path_format
  validates :priority, numericality: { only_integer: true, allow_nil: true, greater_than_or_equal_to: 0, less_than: 100 }
  validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  # TODO: repo_type value depends on packagemanager element
  # https://doc.opensuse.org/projects/kiwi/doc/#sec.description.repository
  validates :repo_type, inclusion: { in: %w(apt-deb rpm-dir rpm-md yast2) }
  validates :replaceable, inclusion: { in: [true, false] }
  validates :imageinclude, :prefer_license, inclusion: { in: [true, false] }, allow_nil: true

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def name
    attributes['alias'] || source_path.tr('/', '_')
  end

  def source_path_format
    return if source_path =~ /^(dir|iso|smb|this):\/\/.+/
    return if source_path =~ /\A#{URI.regexp(['ftp', 'http', 'https', 'plain'])}\z/
    if source_path =~ /^obs:\/\/([^\/]+)\/([^\/]+)$/
      return if Project.valid_name?(Regexp.last_match(1)) && Project.valid_name?(Regexp.last_match(2))
    end
    if source_path =~ /^opensuse:\/\/([^\/]+)\/([^\/]+)$/
      # $1 must be a project name. $2 must be a repository name
      return if Project.valid_name?(Regexp.last_match(1)) && Regexp.last_match(2) =~ /\A[^_:\/\000-\037][^:\/\000-\037]*\Z/
    end

    errors.add(:source_path, "has an invalid format")
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: kiwi_repositories
#
#  id             :integer          not null, primary key
#  image_id       :integer          indexed, indexed => [order]
#  repo_type      :string(255)
#  source_path    :string(255)
#  order          :integer          indexed => [image_id]
#  priority       :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  alias          :string(255)
#  imageinclude   :boolean
#  password       :string(255)
#  prefer_license :boolean
#  replaceable    :boolean
#  username       :string(255)
#
# Indexes
#
#  index_kiwi_repositories_on_image_id            (image_id)
#  index_kiwi_repositories_on_image_id_and_order  (image_id,order) UNIQUE
#
