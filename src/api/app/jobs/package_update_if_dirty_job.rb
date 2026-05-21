class PackageUpdateIfDirtyJob < ApplicationJob
  def perform(package_id)
    package = Package.find_by(id: package_id)
    package.presence&.update_if_dirty
  end
end
