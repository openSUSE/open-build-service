module Webui::BuildstatusHelper
  # rubocop:disable Style/AlignHash
  PACKAGE_STATUS_LIST = ActiveSupport::HashWithIndifferentAccess.new(
      'succeeded'     => 'Package has built successfully and can be used to build further packages.',
      'failed'        => 'The package does not build successfully. No packages have been created. Packages ' \
                       'that depend on this package will be built using any previously created packages, if they exist.',
      'unresolvable'  => 'The build can not begin, because required packages are either missing or not explicitly defined.',
      'broken'        => 'The sources either contain no build description (e.g. specfile), automatic source processing failed or a ' \
                       'merge conflict does exist.',
      'blocked'       => 'This package waits for other packages to be built. These can be in the same or other projects.',
      'scheduled'     => 'A package has been marked for building, but the build has not started yet.',
      'dispatching'   => 'A package is being copied to a build host. This is an intermediate state before building.',
      'building'      => 'The package is currently being built.',
      'signing'       => 'The package has been built successfully and is assigned to get signed.',
      'finished'      => 'The package has been built and signed, but has not yet been picked up by the scheduler. This is an ' \
                       'intermediate state prior to \'succeeded\' or \'failed\'.',
      'disabled'      => 'The package has been disabled from building in project or package metadata.',
      'excluded'      => 'The package build has been disabled in package build description (for example in the .spec file) or ' \
                       'does not provide a matching build description for the target.',
      'unknown'       => 'The scheduler has not yet evaluated this package. Should be a short intermediate state for new packages.'
  )
  # rubocop:enable Style/AlignHash

  def get_package_status_description(status)
    PACKAGE_STATUS_LIST[status] || "status explanation not found"
  end

  def arch_repo_table_cell(repo, arch, package_name)
    status = @statushash[repo][arch][package_name] || { 'package' => package_name }
    status_id = valid_xml_id("id-#{package_name}_#{repo}_#{arch}")
    link_title = status['details']
    if status['code']
      code = status['code']
      theclass = 'status_' + code.gsub(/[- ]/, '_')
    else
      code = ''
      theclass = ' '
    end

    result = "<td class='".html_safe
    result += "#{theclass}"
    result +=" buildstatus nowrap'>".html_safe

    if %w(- unresolvable blocked excluded scheduled).include?(code)
      result += link_to(code, '#', title: link_title, id: status_id, class: code)
    else
      result += link_to(code.gsub(/\s/, '&nbsp;'),
                        {
                            action: :live_build_log, package: package_name, project: @project.to_s,
                            arch: arch, controller: 'package', repository: repo
                        },
                        { title: link_title, rel: 'nofollow' }
                       )
    end

    if !status['code'].nil?
      status_desc = get_package_status_description(status['code'])
      result += " #{sprite_tag 'help', title: status_desc}".html_safe
    end

    result += "</td>".html_safe
  end
end
