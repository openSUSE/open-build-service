module Statistics
  class MaintenanceIncidentsController < ApplicationController
    skip_before_action :extract_user

    def show
      @project = Project.find_by(name: params[:project])
      @maintenance_statistics = MaintenanceStatistic.find_by_project(@project)
    end
  end
end
