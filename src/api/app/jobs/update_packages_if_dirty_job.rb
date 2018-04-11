# frozen_string_literal: true

class UpdatePackagesIfDirtyJob < ApplicationJob
  queue_as :quick

  self.priority = 10

  def perform(project_id)
    project = Project.find_by(id: project_id)
    project.update_packages_if_dirty if project.present?
  end
end
