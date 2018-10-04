module Webui::Packages::JobHistoryHelper
  include Webui::ProjectHelper

  def link_to_package_from_job_history(project, package, jobhistory, is_link)
    title = "Package:#{package} | revision:#{jobhistory.revision}"
    params = { project: project, package: package }
    params = is_link ? params.merge(srcmd5: jobhistory.srcmd5) : params.merge(rev: jobhistory.revision)

    link_to(sprite_tag('req-showdiff', title: title), package_show_path(params))
  end

  def html_class_for_state(state)
    case state
    when 'succeeded'
      'text-primary'
    when 'failed'
      'text-danger'
    end
  end
end
