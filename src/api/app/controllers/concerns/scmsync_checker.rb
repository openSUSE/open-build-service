# Webui::WebuiController includes this concern, so check_scmsync is available to every web UI
# controller. Whatever calls it, as a before_action or directly, should set @project first.

module ScmsyncChecker
  extend ActiveSupport::Concern

  def check_scmsync
    return if @project&.scmsync.blank?

    flash[:error] = "The project #{@project.name} is configured through scmsync. This is not supported by the OBS frontend"
    redirect_to project_show_path(project: @project)
  end
end
