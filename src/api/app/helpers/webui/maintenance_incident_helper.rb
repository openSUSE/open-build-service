module Webui::MaintenanceIncidentHelper
  def incident_label(incident_project, patchinfo)
    incident_number = incident_project.name.rpartition(':').last
    title = patchinfo.dig(:summary) || incident_project.title || incident_project.name

    "#{incident_number}: #{title}"
  end

  def incident_build_icon_class(incident, release_target)
    incident.build_succeeded?(release_target[:reponame]) ? 'text-success fa-check' : 'text-danger fa-exclamation-circle'
  end

  def open_requests_icon(incident)
    requests = BsRequest.list_numbers(roles: %w[target], states: %w[new review], project: incident.name)
    return if requests.none?

    path = (requests.count == 1 ? request_show_path(requests.first) : project_requests_path(project: incident.name))

    content_tag(:div) do
      link_to(path) do
        concat content_tag(:i, nil, class: 'fas fa-exclamation-circle text-danger pr-1')
        concat pluralize(requests.count, 'open request')
      end
    end
  end

  def outgoing_requests_icons(incident)
    requests = BsRequest.list(roles: %w[source], states: %w[new review declined], types: %w[maintenance_release], project: incident.name)
    if requests.present?
      safe_join(outgoing_request_links(requests), '<div/>'.html_safe)
    elsif incident.is_locked?
      content_tag(:div) do
        concat content_tag(:i, nil, class: 'fas fa-lock text-info pr-1')
        concat 'Locked'
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
      link_to(patchinfo[:category], patchinfo_show_path(project: incident.name, package: 'patchinfo'),
              class: "patchinfo-category-#{patchinfo[:category]}")
    else
      link_to(patchinfo_path(project: incident.name, package: 'patchinfo'), method: :post, class: 'text-danger') do
        content_tag(:i, nil, class: 'fas fa-exclamation-circle text-danger')
        'Missing Patchinfo'
      end
    end
  end

  def packages_cell(incident, release_targets_ng)
    release_target = release_targets_ng.values.first
    return if release_target[:packages].blank?
    first_pkg = release_target[:packages].first
    safe_join([
                link_to(first_pkg.name.split('.', 2)[0], package_show_path(project: incident.name, package: first_pkg.name)),
                (', ...' if release_target[:packages].length > 1)
              ])
  end

  def info_cell(incident, patchinfo)
    safe_join([open_requests_icon(incident), outgoing_requests_icons(incident), stopped_icon(patchinfo)])
  end

  def stopped_icon(patchinfo)
    return unless patchinfo[:stopped]
    content_tag(:div) do
      safe_join([content_tag(:i, nil, class: 'fas fa-clock text-info pr-1'), "Stopped: #{patchinfo[:stopped]}"])
    end
  end

  def release_targets_cell(incident, release_targets_ng)
    safe_join(
      [
        release_targets_ng.map do |release_target_project, release_target_ng|
          content_tag(:div) do
            safe_join(
              [
                link_to(project_show_path(project: incident.name)) do
                  content_tag(:i, nil, class: "fas pr-1 #{incident_build_icon_class(incident, release_target_ng)}", title: 'Build results')
                end,
                link_to(release_target_project, project_show_path(project: release_target_project))
              ]
            )
          end
        end
      ]
    )
  end

  private

  def outgoing_request_links(requests)
    requests.map do |rq_out|
      link_to(request_show_path(rq_out['number'])) do
        content_tag(:i, nil, class: "fas fa-flag request-flag-#{rq_out['state']}", title: "Release request in state '#{rq_out['state']}'")
      end
    end
  end
end
