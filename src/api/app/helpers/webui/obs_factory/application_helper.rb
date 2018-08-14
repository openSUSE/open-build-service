module Webui::ObsFactory::ApplicationHelper
  def openqa_links_helper
    ObsFactory::OpenqaJob.openqa_links_url
  end

  def distribution_tests_url(distribution, version = nil)
    path = "#{openqa_links_helper}/tests/overview?distri=opensuse&version=#{distribution.openqa_version}"
    path << "&build=#{version}" if version
    path
  end

  def icon_for_checks(checks)
    return 'eye' if checks.any? { |check| check.state == 'pending' }
    return 'accept' if checks.all? { |check| check.state == 'success' }
    'error'
  end
end
