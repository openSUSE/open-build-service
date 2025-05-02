module Statistics
  class MaintenanceStatisticsController < ApplicationController
    skip_before_action :extract_user, :require_login

    def index
      @project = Project.get_by_name(params[:project])
      @maintenance_statistics = MaintenanceStatistic.find_by_project(@project)
    end
  end
end
