module Webui::MaintenanceIncidentHelper
  def incident_label(incident_project, patchinfo)
    incident_number = incident_project.name.rpartition(':').last
    title = patchinfo[:summary].presence || incident_project.title || incident_project.name

    "#{incident_number}: #{title}"
  end

  def incident_build_icon_class(incident, release_target_repo)
    incident.build_succeeded?(release_target_repo) ? 'text-success fa-check' : 'text-danger fa-exclamation-circle'
  end

  def open_requests_icon(incident)
    requests = BsRequest.list_numbers(roles: %w[target], states: %w[new review], project: incident.name)
    return if requests.none?

    path = (requests.count == 1 ? request_show_path(requests.first) : project_requests_path(project: incident.name))

    tag.div do
      link_to(path) do
        concat(tag.i(nil, class: 'fas fa-exclamation-circle text-danger pe-1'))
        concat(pluralize(requests.count, 'open request'))
      end
    end
  end

  def outgoing_requests_icons(incident)
    requests = BsRequest.list(roles: %w[source], states: %w[new review declined], types: %w[maintenance_release], project: incident.name)
    if requests.present?
      safe_join(outgoing_request_links(requests), '<div/>'.html_safe)
    elsif incident.locked?
      tag.div do
        concat(tag.i(nil, class: 'fas fa-lock text-info pe-1'))
        concat('Locked')
      end
    end
  end

  def patchinfo_data(patchinfo)
    return {} unless patchinfo

    Xmlhash.parse(patchinfo.source_file('_patchinfo')).slice('summary', 'category', 'stopped').with_indifferent_access
  end

  def summary_cell(incident, patchinfo)
    title = incident_label(incident, patchinfo)
    link_to(elide(title, 60, :right), project_show_path(project: incident.name), title: title)
  end

  def category_cell(incident, patchinfo)
    if patchinfo.present?
      link_to(patchinfo[:category], show_patchinfo_path(project: incident.name, package: 'patchinfo'),
              class: "patchinfo-category-#{patchinfo[:category]}")
    else
      link_to(patchinfo_path(project: incident.name, package: 'patchinfo'), method: :post, class: 'text-danger') do
        tag.i(nil, class: 'fas fa-exclamation-circle text-danger')
        'Missing Patchinfo'
      end
    end
  end

  def packages_cell(incident)
    packages = incident.packages_with_release_target.limit(2).pluck(:name)
    return if packages.empty?

    first_package = packages.first
    safe_join([
                link_to(first_package.split('.', 2)[0], package_show_path(project: incident.name, package: first_package)),
                (', ...' if packages.length > 1)
              ])
  end

  def info_cell(incident, patchinfo)
    safe_join([open_requests_icon(incident), outgoing_requests_icons(incident), stopped_icon(patchinfo)])
  end

  def stopped_icon(patchinfo)
    return unless patchinfo[:stopped]

    tag.div do
      safe_join([tag.i(nil, class: 'fas fa-clock text-info pe-1'), "Stopped: #{patchinfo[:stopped]}"])
    end
  end

  def release_targets_cell(incident)
    safe_join(
      [
        incident.target_repositories.map do |target_repo|
          tag.div do
            safe_join(
              [
                link_to(project_show_path(project: incident.name)) do
                  tag.i(nil, class: "fas pe-1 #{incident_build_icon_class(incident, target_repo.name)}", title: 'Build results')
                end,
                link_to(target_repo.project, project_show_path(project: target_repo.project))
              ]
            )
          end
        end
      ]
    )
  end

  private

  def outgoing_request_links(requests)
    requests.map do |request|
      safe_join(
        [
          link_to(request_show_path(request['number'])) do
            tag.i(nil, class: "fas fa-flag pe-1 request-flag-#{request['state']}", title: "Release request in state '#{request['state']}'")
          end,
          # rubocop:disable Rails/OutputSafety
          TimeComponent.new(time: request.created_at).human_time.html_safe
          # rubocop:enable Rails/OutputSafety
        ]
      )
    end
  end
end
