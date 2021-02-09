module Webui::BuildresultHelper
  # NOTE: There is a JavaScript version of this method in project_monitor.js
  def arch_repo_table_cell(repo, arch, package_name, status = nil, enable_help = true)
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

    return build_state(code: code, css_class: css_class, package_name: package_name, status_id: status_id, repo: repo, arch: arch) if feature_enabled?(:responsive_ux)

    capture do
      if enable_help && status['code']
        concat(tag.i(nil, class: ['fa', 'fa-question-circle', 'text-info', 'mr-1'],
                          data: { content: Buildresult.status_description(status['code']), placement: 'top', toggle: 'popover' }))
      end
      if code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])
        concat(link_to(code, 'javascript:void(0);', id: status_id, class: css_class, data: { content: link_title, placement: 'right', toggle: 'popover' }))
      else
        concat(link_to(code.gsub(/\s/, '&nbsp;'),
                       package_live_build_log_path(project: @project.to_s, package: package_name, repository: repo, arch: arch),
                       data: { content: link_title, placement: 'right', toggle: 'popover' }, rel: 'nofollow', class: css_class))
      end
    end
  end

  # NOTE: responsive_ux
  def build_state(attr)
    capture do
      if attr[:code].in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])
        concat(tag.span(attr[:code], id: attr[:status_id], class: "#{attr[:css_class]} toggle-build-info", title: 'Click to keep it open'))
      else
        concat(link_to(attr[:code].gsub(/\s/, '&nbsp;'),
                       package_live_build_log_path(project: @project.to_s, package: attr[:package_name], repository: attr[:repo], arch: attr[:arch]),
                       rel: 'nofollow', class: attr[:css_class]))
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
