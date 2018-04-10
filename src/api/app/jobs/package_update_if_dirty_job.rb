# frozen_string_literal: true
class PackageUpdateIfDirtyJob < ApplicationJob
  def perform(package_id)
    package = Package.find_by(id: package_id)
    package.update_if_dirty if package.present?
  end
end
