# frozen_string_literal: true

class ProjectDoProjectCopyJob < ApplicationJob
  queue_as :quick

  def perform(project_id, params)
    Project.find(project_id).do_project_copy(params)
  end
end
