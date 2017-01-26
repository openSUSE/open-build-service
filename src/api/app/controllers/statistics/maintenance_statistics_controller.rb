module Statistics
  class MaintenanceStatisticsController < ApplicationController
    skip_before_action :extract_user

    def index
      @project = Project.find_by(name: params[:project])
      @maintenance_statistics = MaintenanceStatisticDecorator.wrap(
        MaintenanceStatistic.find_by_project(@project)
      )
    end
  end
end
