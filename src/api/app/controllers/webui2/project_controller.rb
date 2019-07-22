# typed: false
module Webui2::ProjectController
  def webui2_index
    respond_to do |format|
      format.html do
        render :index,
               locals: { important_projects:
                         active_very_important_projects.pluck(:name, :title) }
      end
      format.json { render json: ProjectDatatable.new(params, view_context: view_context, show_all: show_all?) }
    end
  end

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

  def show_all?
    (params[:all].to_s == 'true')
  end

  def active_very_important_projects
    Project.find_by_attribute_type(very_important_project_attribute)
  end

  def very_important_project_attribute
    AttribType.find_by_namespace_and_name!('OBS', 'VeryImportantProject')
  end

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
