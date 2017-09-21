# TODO: Please overwrite this comment with something explaining the model target
class Kiwi::Image < ApplicationRecord
  #### Includes and extends

  #### Constants
  DEFAULT_KIWI_BODY = '<?xml version="1.0" encoding="utf-8"?>
<image schemaversion="6.2" name="suse-13.2-live">
  <description type="system">
  </description>
  <preferences>
    <type image="oem" primary="true" boot="oemboot/suse-13.2"/>
  </preferences>
</image>
'

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  has_one :package, foreign_key: 'kiwi_image_id', class_name: '::Package', dependent: :nullify, inverse_of: :kiwi_image
  has_many :repositories, -> { order(order: :asc) }, dependent: :destroy, index_errors: true
  has_many :package_groups, -> { order(:id) }, dependent: :destroy, index_errors: true
  has_many :kiwi_packages, -> { where(kiwi_package_groups: { kiwi_type: Kiwi::PackageGroup.kiwi_types[:image] }) },
           through: :package_groups, source: :packages, inverse_of: :kiwi_image

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, presence: true
  validate :check_use_project_repositories
  accepts_nested_attributes_for :repositories, allow_destroy: true
  accepts_nested_attributes_for :package_groups, allow_destroy: true
  accepts_nested_attributes_for :kiwi_packages, allow_destroy: true

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
  def self.build_from_xml(xml_string, md5)
    xml = Xmlhash.parse(xml_string)
    return new(name: 'New Image: Please provide a name', md5_last_revision: md5) if xml.blank?
    new_image = new(name: xml['name'], md5_last_revision: md5)

    repositories = [xml["repository"]].flatten.compact
    new_image.use_project_repositories = repositories.any? { |repository| repository['source']['path'] == 'obsrepositories:/' }
    repositories.reject{ |repository| repository['source']['path'] == 'obsrepositories:/' }.each.with_index(1) do |repository, index|
      attributes = {
        repo_type:   repository['type'],
        source_path: repository['source']['path'],
        priority:    repository['priority'],
        order:       index,
        alias:       repository['alias'],
        replaceable: repository['status'] == 'replaceable',
        username:    repository['username'],
        password:    repository['password']
      }
      attributes['imageinclude'] = repository['imageinclude'] == 'true' if repository.key?('imageinclude')
      attributes['prefer_license'] = repository['prefer-license'] == 'true' if repository.key?('prefer-license')

      new_image.repositories.build(attributes)
    end

    [xml["packages"]].flatten.compact.each do |package_group_xml|
      attributes = {
        kiwi_type:    package_group_xml['type'],
        profiles:     package_group_xml['profiles '],
        pattern_type: package_group_xml['patternType']
      }
      package_group = Kiwi::PackageGroup.new(attributes)
      [package_group_xml['package']].flatten.compact.each do |package|
        attributes = {
          name:     package['name'],
          arch:     package['arch'],
          replaces: package['replaces']
        }
        attributes['bootinclude'] = package['bootinclude'] == 'true' if package.key?('bootinclude')
        attributes['bootdelete'] = package['bootdelete'] == 'true' if package.key?('bootdelete')
        package_group.packages.build(attributes)
      end
      new_image.package_groups << package_group
    end
    new_image
  end

  def to_xml
    if package
      kiwi_file = package.kiwi_image_file
      return nil unless kiwi_file
      kiwi_body = package.source_file(kiwi_file)
    else
      kiwi_body = DEFAULT_KIWI_BODY
    end

    doc = Nokogiri::XML::DocumentFragment.parse(kiwi_body)
    image = doc.at_css('image')

    return nil unless image && image.first_element_child

    doc.xpath("image/packages").remove
    xml_packages = package_groups.map(&:to_xml).join("\n")
    image.first_element_child.after(xml_packages)

    doc.xpath("image/repository").remove
    xml_repos = repositories_for_xml.map(&:to_xml).join("\n")
    image.first_element_child.after(xml_repos)

    # Reparser for pretty printing
    Nokogiri::XML(doc.to_xml, &:noblanks).to_xml
  end

  def write_to_backend
    return false unless package

    Package.transaction do
      file_name = package.kiwi_image_file || "#{package.name}.kiwi"
      package.save_file({ filename: file_name, file: to_xml })
      self.md5_last_revision = package.kiwi_file_md5
      save!
    end
  end

  def outdated?
    return false unless package

    package.kiwi_image_outdated?
  end

  def default_package_group
    package_groups.find_or_create_by(kiwi_type: :image)
  end

  def self.find_binaries_by_name(query, project, repositories, options = {})
    finder = /\A#{Regexp.quote(query)}/
    binaries_available(project, options[:use_project_repositories], repositories).select { |package, _| finder.match(package.to_s) }
  end

  def self.binaries_available(project, use_project_repositories, repositories)
    Rails.cache.fetch("kiwi_image_binaries_available_#{project}_#{use_project_repositories}_#{repositories}", expires_in: 5.minutes) do
      if use_project_repositories
        Backend::Api::BuildResults::Binaries.available_in_project(project)
      else
        return [] if repositories.blank?
        obs_repository_paths = repositories.select { |url| url.starts_with?("obs://")}.map {|url| url[6..-1] }
        non_obs_repository_urls = repositories.reject { |url| url.starts_with?("obs://")}
        Backend::Api::BuildResults::Binaries.available_in_repositories(project, non_obs_repository_urls, obs_repository_paths)
      end
    end
  end

  private

  def repositories_for_xml
    if use_project_repositories?
      [Kiwi::Repository.new(source_path: 'obsrepositories:/', repo_type: 'rpm-md')]
    else
      repositories
    end
  end

  def check_use_project_repositories
    return unless use_project_repositories? && repositories.present?

    errors.add(:base,
               "A repository with source_path=\"obsrepositories:/\" has been set. If you want to use it, please remove the other repositories.")
  end
end

# == Schema Information
#
# Table name: kiwi_images
#
#  id                       :integer          not null, primary key
#  name                     :string(255)
#  md5_last_revision        :string(32)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  use_project_repositories :boolean          default(FALSE)
#
