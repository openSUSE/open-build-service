module Webui::BuildresultHelper
  STATUS_ICON = {
    succeeded: 'fa-check text-success',
    failed: 'fa-xmark text-danger',
    unresolvable: 'fa-xmark text-danger',
    broken: 'fa-xmark text-danger',
    blocked: 'fa-shield text-warning',
    scheduled: 'fa-hourglass-half text-warning',
    dispatching: 'fa-plane-departure text-warning',
    building: 'fa-gear text-warning',
    signing: 'fa-signature text-warning',
    finished: 'fa-check text-warning',
    disabled: 'fa-xmark text-gray-500',
    excluded: 'fa-xmark text-gray-500',
    locked: 'fa-lock text-warning',
    deleting: 'fa-eraser text-warning',
    unknown: 'fa-question text-warning'
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
        concat(tag.i(nil, class: ['fas', 'fa-chevron-left', 'expander'], title: "Show build results for this #{collapse_text}"))
        concat(tag.i(nil, class: ['fas', 'fa-chevron-down', 'collapser'], title: "Hide build results for this #{collapse_text}"))
      end
    end
  end

  # Paints an rpmlog line green-ish when the line has a Warning and red when it has an error.
  def colorize_line(line)
    case line
    when /\w+(?:\.\w+)+: W: /
      tag.span(line.strip, style: 'color: olive;')
    when /\w+(?:\.\w+)+: E: /
      tag.span(line.strip, style: 'color: red;')
    else
      line.strip
    end
  end

  def build_status_icon(state)
    STATUS_ICON[state]
  end
end
