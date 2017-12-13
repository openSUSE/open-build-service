module Webui::Packages::BuildReasonHelper
  include Webui::ProjectHelper

  def build_reason_breadcrumb(project, package, *args)
    args.insert(0, link_to_if(params['action'] != 'show', package,
                              controller: '/webui/package', action: :show,
                              project: project, package: package))
    project_bread_crumb(*args)
  end
end
