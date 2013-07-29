class Webui::FlagsController < Webui::BaseController

  # TODO - put in use
  def index
    required_parameters :project_id

    project_name = params[:project_id]
    package_name = params[:package_id]

    if package_name.blank?
      obj = Project.get_by_name(project_name)
    else
      valid_package_name! package_name
      obj = Package.get_by_project_and_name(project_name, package_name, use_source: false)
    end

    render json: obj.expand_flags
  end
end
