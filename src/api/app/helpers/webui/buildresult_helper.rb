module Webui::BuildresultHelper
  STATUS_COLOR_HASH = {
    'succeeded' => 'primary',
    'building' => 'secondary',
    'scheduled' => 'info',
    'signing' => 'dark',
    'finished' => 'dark',
    'unresolvable' => 'danger',
    'broken' => 'danger',
    'failed' => 'danger',
    'disabled' => 'black-50',
    'blocked' => 'black-50',
    'scheduled_warning' => 'warning',
    'unknown' => 'warning'
  }.freeze

  def arch_repo_table_cell(repo, arch, package_name, status = nil, enable_help = true)
    status ||= @statushash[repo][arch][package_name] || { 'package' => package_name }
    status_id = valid_xml_id("id-#{package_name}_#{repo}_#{arch}")
    link_title = status['details']
    if status['code']
      code = status['code']
      theclass = 'status_' + code.gsub(/[- ]/, '_')
      # special case for scheduled jobs with constraints limiting the workers a lot
      theclass = 'status_scheduled_warning' if code == 'scheduled' && link_title.present?
    else
      code = ''
      theclass = ' '
    end

    content_tag(:td, class: [theclass, 'buildstatus', 'nowrap']) do
      if code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])
        concat(link_to(code, '#', title: link_title, id: status_id, class: code))
      else
        concat(link_to(code.gsub(/\s/, '&nbsp;'),
                       package_live_build_log_path(project: @project.to_s, package: package_name, repository: repo, arch: arch),
                       title: link_title, rel: 'nofollow'))
      end

      if enable_help && status['code']
        concat(' ')
        concat(sprite_tag('help', title: Buildresult.status_description(status['code'])))
      end
    end
  end

  def arch_repo_table_cell_webui2(repo, arch, package_name, status = nil, enable_help = true)
    status ||= @statushash[repo][arch][package_name] || { 'package' => package_name }
    status_id = valid_xml_id("id-#{package_name}_#{repo}_#{arch}")
    link_title = status['details']
    if status['code']
      code = status['code']
      theclass = "text-#{STATUS_COLOR_HASH[code.gsub(/[- ]/, '_')]}"
      # special case for scheduled jobs with constraints limiting the workers a lot
      theclass = 'text-warning' if code == 'scheduled' && link_title.present?
    else
      code = ''
      theclass = ' '
    end

    content_tag(:td, class: ['buildstatus', 'nowrap']) do
      if code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])
        concat link_to(code, '#', title: link_title, id: status_id, class: theclass)
      else
        concat link_to(code.gsub(/\s/, '&nbsp;'),
                       package_live_build_log_path(project: @project.to_s, package: package_name, repository: repo, arch: arch),
                       title: link_title, rel: 'nofollow', class: theclass)
      end

      if enable_help && status['code']
        concat ' '
        concat(content_tag(:i, nil, class: ['fa', 'fa-info-circle', 'text-info'], title: Buildresult.status_description(status['code'])))
      end
    end
  end
end
