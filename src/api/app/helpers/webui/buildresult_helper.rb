module Webui::BuildresultHelper
  def arch_repo_table_cell(repo, arch, package_name, status = nil, enable_help = true)
    status ||= @statushash[repo][arch][package_name] || { 'package' => package_name }
    status_id = valid_xml_id("id-#{package_name}_#{repo}_#{arch}")
    link_title = status['details']
    if status['code']
      code = status['code']
      theclass = 'status_' + code.gsub(/[- ]/, '_')
      # special case for scheduled jobs with constraints limiting the workers a lot
      theclass = "status_scheduled_warning" if code == "scheduled" && !link_title.blank?
    else
      code = ''
      theclass = ' '
    end

    result = content_tag(:td, class: [theclass, "buildstatus", "nowrap"]) do
      if %w(- unresolvable blocked excluded scheduled).include?(code)
        concat link_to(code, '#', title: link_title, id: status_id, class: code)
      else
        concat link_to(code.gsub(/\s/, '&nbsp;'),
                       {
                         action: :live_build_log, package: package_name, project: @project.to_s,
                         arch: arch, controller: 'package', repository: repo
                       },
                       { title: link_title, rel: 'nofollow' }
                      )
      end

      if enable_help && status['code']
        concat " "
        concat sprite_tag('help', title: Buildresult.status_description(status['code']))
      end
    end

    result
  end
end
