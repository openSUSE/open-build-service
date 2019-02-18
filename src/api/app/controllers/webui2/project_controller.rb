module Webui2::ProjectController
  def webui2_index
    show_all = (params[:all].to_s == 'true')
    atype = AttribType.find_by_namespace_and_name!('OBS', 'VeryImportantProject')
    @important_projects = Project.find_by_attribute_type(atype).where('name <> ?', 'deleted').pluck(:name, :title)

    if @spider_bot
      render :list_simple, status: params[:nextstatus]
    else
      respond_to do |format|
        format.html { render :list, status: params[:nextstatus] }
        format.json { render json: ProjectDatatable.new(params, view_context: view_context, show_all: show_all) }
      end
    end
  end

  def webui2_show
    @remote_projects = Project.where.not(remoteurl: nil).pluck(:id, :name, :title)
  end

  def webui2_buildresult
    @buildresults = @project.buildresults
    @collapsed_repositories = params.fetch(:collapsed, [])

    respond_to do |format|
      format.js { render 'buildstatus' }
    end
  end
end
