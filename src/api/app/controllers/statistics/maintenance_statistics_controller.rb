module Statistics
  class MaintenanceStatisticsController < ApplicationController
    skip_before_action :extract_user, :require_login

    def index
      @project = Project.get_by_name(params[:project])
      if @project.is_a?(String)
        # FIXME: This could be simplified by redirecting to the remote instead
        remote_instance, remote_project = Project.find_remote_project(@project)
        remote_response = ActiveXML::Transport.load_external_url(
          "#{remote_instance.remoteurl}#{maintenance_statistics_path(project: remote_project)}"
        )
        if remote_response
          render xml: remote_response
        else
          render_error status: 404, errorcode: 'remote_project', message: "Project '#{@project}' not found"
        end
      else
        @maintenance_statistics = MaintenanceStatisticDecorator.wrap(
          MaintenanceStatistic.find_by_project(@project)
        )
      end
    end
  end
end
