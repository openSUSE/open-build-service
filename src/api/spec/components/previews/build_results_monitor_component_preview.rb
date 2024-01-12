class BuildResultsMonitorComponentPreview < ViewComponent::Preview
  FAKE_RAW_DATA = [
    { architecture: 'x86_64', repository: 'openSUSE_Leap_42.2', status: 'excluded', package_name: 'source_package', project_name: 'source_project', repository_status: 'excluded', is_repository_in_db: true },
    { architecture: 'i586', repository: 'openSUSE_Tumbleweed', status: 'unresolvable', package_name: 'source_package', project_name: 'source_project', repository_status: 'unresolvable', is_repository_in_db: true },
    { architecture: 's390', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project', repository_status: 'published', is_repository_in_db: true },
    { architecture: 'x86_64', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project', repository_status: 'published', is_repository_in_db: true },
    { architecture: 's390', repository: 'openSUSE_Tumbleweed', status: 'building', package_name: 'source_package', project_name: 'source_project', repository_status: 'building', is_repository_in_db: true }
  ].freeze

  # Preview at http://HOST:PORT/rails/view_components/request_build_results_monitor
  def monitor_page
    render(BuildResultsMonitorComponent.new(raw_data: FAKE_RAW_DATA))
  end
end
