# frozen_string_literal: true

class ProjectDoProjectReleaseJob < ApplicationJob
  queue_as :quick

  def perform(project_id, params)
    Project.find(project_id).do_project_release(params)
  end
end
