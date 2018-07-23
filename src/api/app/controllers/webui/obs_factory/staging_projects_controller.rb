module Webui::ObsFactory
  class StagingProjectsController < Webui::ObsFactory::ApplicationController
    respond_to :json, :html

    before_action :require_distribution
    before_action :require_project_name, only: [:show]

    def index
      respond_to do |format|
        format.html do
          @staging_projects = ::ObsFactory::StagingProjectPresenter.sort(@distribution.staging_projects_all)
          @backlog_requests = BsRequest.with_open_reviews_for(by_group: @distribution.staging_manager, target_project: @distribution.name)
          @requests_state_new = BsRequest.in_state_new(by_group: @distribution.staging_manager, target_project: @distribution.name)

          staging_project = Project.find_by_name("#{@distribution.project}:Staging")
          dashboard_package = Package.find_by_project_and_name(staging_project.name, 'dashboard')

          if dashboard_package && dashboard_package.file_exists?('ignored_requests')
            file = ::Backend::Api::Sources::Package.file(staging_project.name, dashboard_package.name, 'ignored_requests')
            @ignored_requests = YAML.load(file)
          end

          if @ignored_requests
            @backlog_requests_ignored = @backlog_requests.select { |req| @ignored_requests.key?(req.number) }
            @backlog_requests = @backlog_requests.select { |req| !@ignored_requests.key?(req.number) }
            @requests_state_new = @requests_state_new.select { |req| !@ignored_requests.key?(req.number) }
            @backlog_requests_ignored.sort! { |x,y| x.first_target_package <=> y.first_target_package }
          else
            @backlog_requests_ignored = []
          end
          @backlog_requests.sort! { |x,y| x.first_target_package <=> y.first_target_package }
          @requests_state_new.sort! { |x,y| x.first_target_package <=> y.first_target_package }
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
        redirect_to main_app.root_path, flash: { error: "#{params[:project]} is not a valid openSUSE distribution, can't offer dashboard" }
      end
    end

    def require_project_name
      @staging_project = ::ObsFactory::StagingProject.find(@distribution, params[:project_name])
      unless @staging_project
        redirect_to main_app.root_path, flash: { error: "#{params[:project_name]} is not a valid staging project" }
      end
    end
  end
end
