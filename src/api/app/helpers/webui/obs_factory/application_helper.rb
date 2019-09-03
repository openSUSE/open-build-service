module Webui::ObsFactory::ApplicationHelper
  def openqa_links_helper
    ObsFactory::OpenqaJob.openqa_links_url
  end

  def distribution_tests_url(distribution, version = nil)
    path = "#{openqa_links_helper}/tests/overview?distri=opensuse&version=#{distribution.openqa_version}"
    path << "&build=#{version}" if version
    path
  end

  def icon_for_checks(checks, missing_checks)
    return 'eye' if missing_checks.present?
    return 'accept' if checks.blank?
    return 'eye' if checks.any? { |check| check.state == 'pending' }
    return 'accept' if checks.all? { |check| check.state == 'success' }
    'error'
  end

  def project_bread_crumb(*args)
    @crumb_list = [link_to('Projects', project_list_public_path)]
    return if @spider_bot
    # FIXME: should also work for remote
    if @project && @project.is_a?(Project) && !@project.new_record?
      prj_parents = nil
      if @namespace # corner case where no project object is available
        prj_parents = Project.parent_projects(@namespace)
      else
        # FIXME: Some controller's @project is a Project object whereas other's @project is a String object.
        prj_parents = Project.parent_projects(@project.to_s)
      end
      project_list = []
      prj_parents.each do |name, short_name|
        project_list << link_to(short_name, project_show_path(project: name))
      end
      @crumb_list << project_list unless project_list.empty?
    end
    @crumb_list += args
  end
end
