class PackageUpdateIfDirtyJob < ApplicationJob
  def perform(package_id)
    Package.find(package_id).update_if_dirty
  end
end
