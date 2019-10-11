module Staging
  class StagingController < ApplicationController
    private

    def set_project
      @project = Project.get_by_name(params[:staging_workflow_project])
    rescue Project::UnknownObjectError
      render_error(
        status: 404,
        errorcode: 'not_found',
        message: "Project '#{params[:staging_workflow_project]}' not found."
      )
    end

    def set_staging_workflow
      @staging_workflow = @project.staging
      return if @staging_workflow

      render_error(
        status: 404,
        errorcode: 'not_found',
        message: "Project #{@project} doesn't have an asociated Staging Workflow"
      )
    end
  end
end
