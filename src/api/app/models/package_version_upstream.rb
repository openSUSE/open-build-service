# Model to track the upstream version of a package.
class PackageVersionUpstream < PackageVersion
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)

  #### Callbacks macros: before_save, after_save, etc.
  after_create :create_package_upstream_version_source_changed_event
  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
  private

  def create_package_upstream_version_source_changed_event
    local_version = package.latest_local_version&.version

    Event::PackageUpstreamVersionSourceChanged.create(local_version: local_version, upstream_version: version,
                                                      package: package.name, project: package.project.name)
  end
end

# == Schema Information
#
# Table name: package_versions
#
#  id         :bigint           not null, primary key
#  type       :string(255)      not null
#  version    :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  package_id :integer          not null, indexed
#
# Indexes
#
#  index_package_versions_on_package_id  (package_id)
#
# Foreign Keys
#
#  fk_rails_...  (package_id => packages.id)
#
