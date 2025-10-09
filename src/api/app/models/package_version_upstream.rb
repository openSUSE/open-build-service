# Model to track the upstream version of a package.
class PackageVersionUpstream < PackageVersion
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)

  #### Callbacks macros: before_save, after_save, etc.
  after_save :check_for_outdated_local_package_version
  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
  private

  def check_for_outdated_local_package_version
    local_version_string = package.latest_local_version&.version
    return if local_version_string.blank?

    begin
      local_version_object = Gem::Version.create(local_version_string.gsub(/[^0-9A-Za-z.]/, '.'))
      upstream_version_object = Gem::Version.create(version.gsub(/[^0-9A-Za-z.]/, '.'))

      if (local_version_object <=> upstream_version_object) == -1
        Event::PackageOutOfDate.create(local_version: local_version_string, upstream_version: version,
                                       package: package.name, project: package.project.name)
      end
    rescue ArgumentError
      nil
    end
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
