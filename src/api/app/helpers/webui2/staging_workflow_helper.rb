module Webui2::StagingWorkflowHelper
  def projects_without_requests
    projects = @staging_workflow.staging_projects.without_staged_requests.with_alphabetic_identifier

    return 'None' if projects.empty?
    projects.map { |project| link_to(project.staging_identifier, project_show_path(project.name)) }.sort.join(' - ').html_safe
  end

  def list_of_requests(requests)
    limit = 5
    size = requests.size

    if size.zero?
      'Empty'
    else
      capture_haml do
        haml_tag :ul do
          requests.first(limit).each do |request|
            haml_tag :li do
              haml_concat(link_to(elide(request.first_target_package, 19), request_show_path(request.number)))
            end
          end

          if size > limit
            haml_tag(:li, "... #{size - limit} more")
          end
        end
      end
    end
  end
end
