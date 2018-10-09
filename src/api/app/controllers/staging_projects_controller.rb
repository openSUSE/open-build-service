class StagingProjectsController < ApplicationController
  before_action :set_project

  def requests_to_review
    @reviews = BsRequest.with_open_reviews_for(by_project: @project.name)
  end

  private

  def set_project
    # We've started to use project_name for new routes...
    @project = Project.find_by(name: params[:project])
    raise ActiveRecord::RecordNotFound unless @project
  end
end
