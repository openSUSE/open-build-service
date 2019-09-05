module Webui2::ProjectController
  def webui2_show
    @remote_projects = Project.where.not(remoteurl: nil).pluck(:id, :name, :title)
  end

  def webui2_subprojects
    respond_to do |format|
      format.html
      format.json do
        render json: ProjectDatatable.new(params, view_context: view_context, projects: project_for_datatable)
      end
    end
  end

  private

  def project_for_datatable
    case params[:type]
    when 'sibling project'
      @project.siblingprojects
    when 'subproject'
      @project.subprojects.order(:name)
    when 'parent project'
      @project.ancestors.order(:name)
    end
  end
end
