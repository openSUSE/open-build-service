module Webui::NotificationHelper
  def link_to_all
    parameters = params[:type] ? { type: params[:type] } : {}
    if params['show_all'] # already showing all
      link_to('Show less', my_notifications_path(parameters), class: 'btn btn-sm btn-secondary ml-2')
    else
      parameters.merge!({ show_all: 1 })
      link_to('Show all', my_notifications_path(parameters), class: 'btn btn-sm btn-secondary ml-2')
    end
  end

  def project_list(projects)
    hash_projects = Hash.new(0)
    projects.each { |project| hash_projects[project] += 1 }

    hash_projects.sort_by(&:last).reverse
  end
end
