class UpdatePackagesIfDirtyJob < ApplicationJob
  queue_as :quick

  self.priority = 10

  def perform(project_id)
    project = Project.find_by(id: project_id)
    project.presence&.update_packages_if_dirty
  end
end
