class Webui::SitemapsController < Webui::WebuiController
  def index
    render layout: false, content_type: 'application/xml'
  end

  def projects
    @projects_names = Project.pluck(:name)

    render layout: false, content_type: 'application/xml'
  end

  def packages
    project_name = params[:project_name].to_s

    projects_table = Project.arel_table

    predication =
      if %r{home}.match?(project_name)
        projects_table[:name].matches("#{project_name}%")
      elsif project_name == 'opensuse'
        projects_table[:name].matches('openSUSE:%')
      else
        projects_table[:name].does_not_match_all(['home:%', 'DISCONTINUED:%', 'openSUSE:%'])
      end

    @packages = Project.joins(:packages).where(predication).pluck('projects.name', 'packages.name')

    render layout: false, content_type: 'application/xml'
  end
end
