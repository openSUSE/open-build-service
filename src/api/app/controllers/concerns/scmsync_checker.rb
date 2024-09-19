# The controller which includes this concern, should set @project.

module ScmsyncChecker
  extend ActiveSupport::Concern

  def check_scmsync
    return if @project&.scmsync.blank?

    flash[:error] = "The project #{@project.name} is configured through scmsync. This is not supported by the OBS frontend"
    redirect_to project_show_path(project: @project)
  end
end
