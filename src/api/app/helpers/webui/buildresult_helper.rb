module Webui::BuildresultHelper
  STATUS_ICON = {
    succeeded: 'fa-check',
    failed: 'fa-circle-exclamation',
    unresolvable: 'fa-circle-exclamation',
    broken: 'fa-circle-exclamation',
    blocked: 'fa-shield',
    scheduled: 'fa-hourglass-half',
    dispatching: 'fa-plane-departure',
    building: 'fa-gear',
    signing: 'fa-signature',
    finished: 'fa-check',
    disabled: 'fa-ban',
    excluded: 'fa-ban',
    locked: 'fa-lock',
    deleting: 'fa-eraser',
    unknown: 'fa-question'
  }.with_indifferent_access.freeze

  CATEGORY_ICON = {
    succeeded: 'fa-check',
    failed: 'fa-circle-exclamation',
    blocked: 'fa-shield',
    processing: 'fa-gear',
    disabled: 'fa-ban'
  }.with_indifferent_access.freeze

  CATEGORY_COLOR = {
    succeeded: 'text-bg-success',
    failed: 'text-bg-danger',
    blocked: 'text-bg-warning',
    processing: 'text-bg-info',
    disabled: 'text-bg-light border'
  }.with_indifferent_access.freeze

  def repository_expanded?(collapsed_repositories, repository_name, key = 'project')
    return collapsed_repositories[key].exclude?(repository_name) if collapsed_repositories[key]

    true
  end

  def collapse_link(expanded, main_name, repository_name = nil)
    collapse_id = repository_name ? "#{main_name}-#{repository_name}" : main_name
    collapse_text = repository_name ? 'repository' : 'package'

    link_to('#', aria: { controls: "collapse-#{collapse_id}", expanded: expanded }, class: 'px-2 ms-auto',
                 data: { 'bs-toggle': 'collapse' }, href: ".collapse-#{collapse_id}", role: 'button') do
      capture do
        concat(tag.i(nil, class: %w[fas fa-chevron-left expander], title: "Show build results for this #{collapse_text}"))
        concat(tag.i(nil, class: %w[fas fa-chevron-down collapser], title: "Hide build results for this #{collapse_text}"))
      end
    end
  end

  # Paints an rpmlog line green-ish when the line has a Warning and red when it has an error.
  def colorize_line(line)
    case line
    when /\w+(?:\.\w+)+: W: /
      tag.span(line, style: 'color: olive;')
    when /\w+(?:\.\w+)+: E: /
      tag.span(line, style: 'color: red;')
    else
      line
    end
  end

  def build_status_icon(status)
    STATUS_ICON[status]
  end

  def build_status_category_icon(status)
    CATEGORY_ICON[status]
  end

  def build_status_category_color(status)
    CATEGORY_COLOR[Buildresult::STATUS_CATEGORIES_MAP[status]]
  end

  def live_build_log_url(status, project, package, repository, architecture)
    return if %w[unresolvable blocked excluded scheduled].include?(status)

    package_live_build_log_path(project: project,
                                package: package,
                                repository: repository,
                                arch: architecture)
  end
end
