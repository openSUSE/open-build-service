module Webui::BuildresultHelper
  # NOTE: There is a JavaScript version of this method in project_monitor.js
  def arch_repo_table_cell(repo, arch, package_name, status = nil, enable_help = true)
    status ||= @statushash[repo][arch][package_name] || { 'package' => package_name }
    status_id = valid_xml_id("id-#{package_name}_#{repo}_#{arch}")
    link_title = status['details']
    code = ''
    theclass = ' '

    if status['code']
      code = status['code']
      theclass = "build-state-#{code}"
      # special case for scheduled jobs with constraints limiting the workers a lot
      theclass = 'text-warning' if code == 'scheduled' && link_title.present?
    end

    capture do
      if enable_help && status['code']
        concat(content_tag(:i, nil, class: ['fa', 'fa-question-circle', 'text-info', 'mr-1'],
                                    data: { content: Buildresult.status_description(status['code']), placement: 'top', toggle: 'popover' }))
      end
      if code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])
        concat(link_to(code, 'javascript:void(0);', id: status_id, class: theclass, data: { content: link_title, placement: 'right', toggle: 'popover' }))
      else
        concat(link_to(code.gsub(/\s/, '&nbsp;'),
                       package_live_build_log_path(project: @project.to_s, package: package_name, repository: repo, arch: arch),
                       data: { content: link_title, placement: 'right', toggle: 'popover' }, rel: 'nofollow', class: theclass))
      end
    end
  end

  def repository_expanded?(collapsed_repositories, repository_name, key = 'project')
    return collapsed_repositories[key].exclude?(repository_name) if collapsed_repositories[key]
    true
  end
end
