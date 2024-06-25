class BuildResultsMonitorComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/build_results_monitor_component

  FAKE_RAW_DATA = [
    { architecture: 'x86_64', repository: 'openSUSE_Leap_42.2', status: 'excluded', package_name: 'source_package', project_name: 'source_project', repository_status: 'excluded', is_repository_in_db: true },
    { architecture: 'i586', repository: 'openSUSE_Tumbleweed', status: 'unresolvable', package_name: 'source_package', project_name: 'source_project', repository_status: 'unresolvable', is_repository_in_db: true,
      details: 'missing dependencies..' },
    { architecture: 's390', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project', repository_status: 'published', is_repository_in_db: true },
    { architecture: 'x86_64', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project', repository_status: 'published', is_repository_in_db: true },
    { architecture: 's390', repository: 'openSUSE_Tumbleweed', status: 'building', package_name: 'source_package', project_name: 'source_project', repository_status: 'building', is_repository_in_db: true }
  ].freeze

  def monitor_page
    render(BuildResultsMonitorComponent.new(raw_data: FAKE_RAW_DATA, filter_url: '', filters: {}))
  end

  def monitor_page_with_filters
    render(BuildResultsMonitorComponent.new(raw_data: FAKE_RAW_DATA, filter_url: '', filters: %w[repo_openSUSE_Tumbleweed status_unresolvable arch_i586]))
  end
end
