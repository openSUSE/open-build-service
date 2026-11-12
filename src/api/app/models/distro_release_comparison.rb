# Compares the local package versions (PackageVersionLocal) of two releases of the same distro
class DistroReleaseComparison
  STATUSES = %i[newer older changed same only_in_base only_in_target].freeze

  Row = Struct.new(:package_name, :base_version, :target_version, :status)

  attr_reader :base_release, :target_release

  def initialize(base_release:, target_release:)
    @base_release = base_release
    @target_release = target_release
  end

  def rows
    @rows ||= begin
      base_versions = base_release.latest_local_package_versions
      target_versions = target_release.latest_local_package_versions

      (base_versions.keys | target_versions.keys).sort.map do |package_name|
        Row.new(package_name, base_versions[package_name], target_versions[package_name],
                status(package_name, base_versions, target_versions))
      end
    end
  end

  def counts
    @counts ||= rows.group_by(&:status).transform_values(&:count)
  end

  private

  def status(package_name, base_versions, target_versions)
    return :only_in_target unless base_versions.key?(package_name)
    return :only_in_base unless target_versions.key?(package_name)

    version_status(base_versions[package_name], target_versions[package_name])
  end

  def version_status(base_version, target_version)
    return :same if base_version == target_version
    return :changed if base_version.nil? || target_version.nil?

    { 1 => :newer, 0 => :same, -1 => :older }.fetch(RpmVersion.compare(target_version, base_version))
  end
end
