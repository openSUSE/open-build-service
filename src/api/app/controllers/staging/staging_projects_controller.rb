class Staging::StagingProjectsController < ApplicationController
  skip_before_action :require_login

  before_action :set_main_project

  def index
    if @main_project.staging
      @staging_workflow = @main_project.staging
      @staging_projects = @staging_workflow.staging_projects
    else
      render_error status: 400, errcode: 'project_has_no_staging_workflow'
    end
  end

  def show
    @staging_project = @main_project.staging.staging_projects.find_by!(name: params[:name])
  end

  private

  def set_main_project
    @main_project = Project.find_by!(name: params[:staging_main_project_name])
  end
end
