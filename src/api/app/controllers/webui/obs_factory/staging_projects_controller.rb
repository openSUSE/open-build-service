# typed: false
module Webui::ObsFactory
  class StagingProjectsController < Webui::ObsFactory::ApplicationController
    respond_to :json, :html

    before_action :require_distribution
    before_action :require_project_name, only: [:show]

    def index
      respond_to do |format|
        format.html do
          @staging_projects = ::ObsFactory::StagingProjectPresenter.sort(@distribution.staging_projects_all)
          @backlog_requests = BsRequest.with_open_reviews_for(by_group: @distribution.staging_manager)
                                       .with_target_project(@distribution.name)
          @requests_state_new = BsRequest.new_with_reviews_for(by_group: @distribution.staging_manager)
                                         .with_target_project(@distribution.name)

          staging_project = Project.find_by_name("#{@distribution.project}:Staging")
          @ignored_requests = staging_project.dashboard.try(:ignored_requests)

          if @ignored_requests
            @backlog_requests_ignored = @backlog_requests.where(number: @ignored_requests.keys)
            @backlog_requests = @backlog_requests.where.not(number: @ignored_requests.keys)
            @requests_state_new = @requests_state_new.where.not(number: @ignored_requests.keys)
          else
            @backlog_requests_ignored = BsRequest.none
          end
          # For the breadcrumbs
          @project = @distribution.project
        end
        format.json { render json: @distribution.staging_projects_all }
      end
    end

    def show
      respond_to do |format|
        format.html do
          @staging_project = ::ObsFactory::StagingProjectPresenter.new(@staging_project)
          # For the breadcrumbs
          @project = @distribution.project
        end
        format.json { render json: @staging_project }
      end
    end

    private

    def require_distribution
      @distribution = ::ObsFactory::Distribution.find(params[:project])
      unless @distribution
        redirect_to root_path, flash: { error: "#{params[:project]} is not a valid openSUSE distribution, can't offer dashboard" }
      end
    end

    def require_project_name
      @staging_project = ::ObsFactory::StagingProject.find(@distribution, params[:project_name])
      unless @staging_project
        redirect_to root_path, flash: { error: "#{params[:project_name]} is not a valid staging project" }
      end
    end
  end
end
