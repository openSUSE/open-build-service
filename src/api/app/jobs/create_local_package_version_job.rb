class CreateLocalPackageVersionJob < ApplicationJob
  queue_as :slow_user

  def perform(package_id, version)
    PackageVersionLocal.create(version: version, package: Package.find(package_id))
  end
end
