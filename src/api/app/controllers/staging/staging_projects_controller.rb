class Staging::StagingProjectsController < ApplicationController
  skip_before_action :require_login

  def show
    @staging_project = Staging::StagingProject.get_by_name(params[:name])
  end
end
