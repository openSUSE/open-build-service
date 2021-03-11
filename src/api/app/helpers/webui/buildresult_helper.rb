module Webui::BuildresultHelper
  # NOTE: There is a JavaScript version of this method in project_monitor.js
  # TODO: Refactor this! A good start would be to never ever use an instance variable in a helper method... please!
  def arch_repo_table_cell(repo, arch, package_name, status = nil)
    status ||= @statushash[repo][arch][package_name] || { 'package' => package_name }
    status_id = valid_xml_id("id-#{package_name}_#{repo}_#{arch}")
    link_title = status['details']
    code = ''
    css_class = ' '

    if status['code']
      code = status['code']
      css_class = "build-state-#{code}"
      # special case for scheduled jobs with constraints limiting the workers a lot
      css_class = 'text-warning' if code == 'scheduled' && link_title.present?
    end

    capture do
      if code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])
        concat(tag.span(code, id: status_id, class: "#{css_class} toggle-build-info", title: 'Click to keep it open'))
      else
        concat(link_to(code.gsub(/\s/, '&nbsp;'),
                       package_live_build_log_path(project: @project.to_s, package: package_name, repository: repo, arch: arch),
                       rel: 'nofollow', class: css_class))
      end
    end
  end

  def repository_expanded?(collapsed_repositories, repository_name, key = 'project')
    return collapsed_repositories[key].exclude?(repository_name) if collapsed_repositories[key]

    true
  end

  def collapse_link(expanded, main_name, repository_name = nil)
    collapse_id = repository_name ? "#{main_name}-#{repository_name}" : main_name
    collapse_text = repository_name ? 'repository' : 'package'

    link_to('#', aria: { controls: "collapse-#{collapse_id}", expanded: expanded }, class: 'px-2 ml-auto',
                 data: { toggle: 'collapse' }, href: ".collapse-#{collapse_id}", role: 'button') do
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
end
