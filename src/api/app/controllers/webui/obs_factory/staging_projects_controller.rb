module ObsFactory
  class StagingProjectsController < ApplicationController
    respond_to :json, :html

    before_action :require_distribution

    def require_distribution
      @distribution = Distribution.find(params[:project])
      unless @distribution
        redirect_to main_app.root_path, flash: { error: "#{params[:project]} is not a valid openSUSE distribution, can't offer dashboard" }
      end
    end

    def index
      respond_to do |format|
        format.html do
          @staging_projects = StagingProjectPresenter.sort(@distribution.staging_projects_all)
          @backlog_requests = Request.with_open_reviews_for(by_group: @distribution.staging_manager, target_project: @distribution.name)
          @requests_state_new = Request.in_state_new(by_group: @distribution.staging_manager, target_project: @distribution.name)
          file = PackageFile.new(
            project_name: "#{params[:project]}:Staging",
            package_name: "dashboard",
            name: "ignored_requests")
          unless file.to_s.nil?
            @ignored_requests = YAML.load(file.to_s)
          end
          if !@ignored_requests.nil? and @ignored_requests
            @backlog_requests_ignored = @backlog_requests.select { |req| @ignored_requests.key?(req.number) }
            @backlog_requests = @backlog_requests.select { |req| !@ignored_requests.key?(req.number) }
            @requests_state_new = @requests_state_new.select { |req| !@ignored_requests.key?(req.number) }
            @backlog_requests_ignored.sort! { |x,y| x.package <=> y.package }
          else
            @backlog_requests_ignored = []
          end
          @backlog_requests.sort! { |x,y| x.package <=> y.package }
          @requests_state_new.sort! { |x,y| x.package <=> y.package }
          # For the breadcrumbs
          @project = @distribution.project
        end
        format.json { render json: @distribution.staging_projects_all }
      end
    end

    before_action :require_id, only: [:show]

    def require_id
      @staging_project = StagingProject.find(@distribution, params[:id])
      unless @staging_project
        redirect_to main_app.root_path, flash: { error: "#{params[:id]} is not a valid staging project" }
      end
    end

    def show
      respond_to do |format|
        format.html do
          @staging_project = StagingProjectPresenter.new(@staging_project)
          # For the breadcrumbs
          @project = @distribution.project
        end
        format.json { render json: @staging_project }
      end
    end
  end
end
