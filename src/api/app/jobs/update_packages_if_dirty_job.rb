class UpdatePackagesIfDirtyJob < ApplicationJob
  queue_as :quick

  self.priority = 10

  def perform(project_id)
    Project.find(project_id).update_packages_if_dirty
  end
end
