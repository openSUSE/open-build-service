# TODO: Please overwrite this comment with something explaining the model target
module Kiwi
  class Repository < ApplicationRecord
    #### Includes and extends

    #### Constants
    REPO_TYPES = ['rpm-md', 'apt-deb'].freeze

    #### Self config

    #### Attributes

    #### Associations macros (Belongs to, Has one, Has many)
    belongs_to :image

    #### Callbacks macros: before_save, after_save, etc.
    before_validation :map_to_allowed_repository_types, on: :create

    #### Scopes (first the default_scope macro if is used)

    #### Validations macros
    validates :alias, :source_path, uniqueness: { scope: :image, message: "'%{value}' has already been taken" }, allow_blank: true
    validates :source_path, presence: { message: 'can\'t be nil' }
    validate :source_path_format
    validates :priority, numericality: { only_integer: true, allow_nil: true, greater_than_or_equal_to: 0,
                                        less_than: 100, message: 'must be between 0 and 99' }
    validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    # TODO: repo_type value depends on packagemanager element
    # https://doc.opensuse.org/projects/kiwi/doc/#sec.description.repository
    validates :repo_type, inclusion: { in: REPO_TYPES, message: "'%{value}' is not included in the list" }
    validates :replaceable, inclusion: { in: [true, false], message: 'has to be a boolean' }
    validates :imageinclude, :prefer_license, inclusion: { in: [true, false], message: 'has to be a boolean' }, allow_nil: true
    validates_associated :image, on: :update
    validates :order, uniqueness: {
      scope: :image_id,
      message: lambda do |object, data|
        "##{data[:value]} has already been taken for the Image ##{object.image_id}"
      end
    }

    #### Class methods using self. (public and then private)

    #### To define class methods as private use private_class_method
    #### private

    #### Instance methods (public and then protected/private)
    def name
      return source_path.to_s.tr('/', '_') if attributes['alias'].blank?
      attributes['alias']
    end

    def source_path_format
      return if source_path == 'obsrepositories:/'
      return if source_path =~ /^(dir|iso|smb|this):\/\/.+/
      return if source_path =~ /\A#{URI.regexp(['ftp', 'http', 'https', 'plain'])}\z/
      if source_path_for_obs_repository?
        return if repo_type == 'rpm-md'
        errors.add(:repo_type, "should be 'rpm-md' for obs:// repositories")
      end
      return if source_path_for_opensuse_repository?
      errors.add(:source_path, 'has an invalid format')
    end

    def to_xml
      repo_attributes = { type: repo_type }
      repo_attributes[:priority] = priority if priority.present?
      repo_attributes[:alias] = self.alias if self.alias.present?
      if username.present?
        repo_attributes[:username] = username
        repo_attributes[:password] = password
      end
      repo_attributes[:status] = 'replaceable' if replaceable
      repo_attributes[:imageinclude] = true if imageinclude
      repo_attributes['prefer-license'] = true if prefer_license

      builder = Nokogiri::XML::Builder.new
      builder.repository(repo_attributes) do |repo|
        repo.source(path: source_path)
      end

      builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT)
    end

    def obs_source_path?
      source_path && source_path.match(/^obs:\/\/([^\/]+)\/([^\/]+)$/).present?
    end

    def project_for_type_obs
      return '' unless source_path
      source_path.match(/^obs:\/\/([^\/]+)\/([^\/]+)$/).try(:[], 1)
    end

    def repository_for_type_obs
      return '' unless source_path
      source_path.match(/^obs:\/\/([^\/]+)\/([^\/]+)$/).try(:[], 2)
    end

    private

    def source_path_for_obs_repository?
      source_path =~ /^obs:\/\/([^\/]+)\/([^\/]+)$/ && Project.valid_name?(Regexp.last_match(1)) && Project.valid_name?(Regexp.last_match(2))
    end

    def source_path_for_opensuse_repository?
      # $1 must be a project name. $2 must be a repository name
      source_path =~ /^opensuse:\/\/([^\/]+)\/([^\/]+)$/ &&
        Project.valid_name?(Regexp.last_match(1)) &&
        Regexp.last_match(2) =~ /\A[^_:\/\000-\037][^:\/\000-\037]*\Z/
    end

    def map_to_allowed_repository_types
      self.repo_type = 'rpm-md' unless repo_type.in?(REPO_TYPES)
    end
  end
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
