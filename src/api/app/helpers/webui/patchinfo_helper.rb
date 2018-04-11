# frozen_string_literal: true

module Webui::PatchinfoHelper
  include Webui::ProjectHelper
  def patchinfo_bread_crumb(*args)
    args.insert(0, link_to(@package, package_show_path(project: @project, package: @package)))
    project_bread_crumb(*args)
  end
end
