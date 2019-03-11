class Staging::StagingProjectsController < ApplicationController
  before_action :require_login, except: [:index, :show]

  before_action :set_main_project
  before_action :set_staging_project, only: [:show, :destroy]

  def index
    if @main_project.staging
      @staging_workflow = @main_project.staging
      @staging_projects = @staging_workflow.staging_projects
    else
      render_error status: 400, errcode: 'project_has_no_staging_workflow'
    end
  end

  def show; end

  def copy
    authorize @main_project.staging

    StagingProjectCopyJob.perform_later(params[:staging_main_project_name], params[:staging_project_name], params[:staging_project_copy_name], User.current.id)

    render_ok
  end

  def destroy
    authorize @main_project.staging

    if @staging_project.destroy
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Error while deleting staging project: #{result.errors.join(' ')}"
      )
    end
  end

  private

  def set_main_project
    @main_project = Project.find_by!(name: params[:staging_main_project_name])
  end

  def set_staging_project
    @staging_project = @main_project.staging.staging_projects.find_by!(name: params[:name])
  end
end
