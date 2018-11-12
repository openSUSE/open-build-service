class Staging::ProjectsController < ApplicationController
  before_action :set_project

  private

  def set_project
    @project = Staging::StagingProject.find_by(name: params[:project])
    raise ActiveRecord::RecordNotFound unless @project
  end
end
