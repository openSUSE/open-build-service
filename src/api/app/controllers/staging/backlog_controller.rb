class Staging::BacklogController < ApplicationController
  before_action :require_login, except: [:index]
  before_action :set_project
  before_action :set_staging_workflow

  def index
    @backlog = @staging_workflow.unassigned_requests
  end

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

    raise InvalidParameterError, "Project #{params[:staging_workflow_project]} doesn't have an asociated Staging Workflow"
  end
end
