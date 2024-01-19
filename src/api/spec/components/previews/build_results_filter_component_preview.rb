class BuildResultsFilterComponentPreview < ViewComponent::Preview
  DATA = {
    package_names: ['package_a', 'package_b', 'package_c'],
    repository_names: ['repo_a', 'repo_b'],
    architecture_names: ['arch_a', 'arch_b', 'arch_c'],
    status_names: ['broken', 'succeeded', 'failed']
  }.with_indifferent_access.freeze

  SELECTED_FITLERS = ['repo_repo_a', 'package_package_a', 'status_succeeded', 'status_failed', 'arch_arch_a', 'arch_arch_b'].freeze

  # Preview at http://HOST:PORT/rails/view_components/build_results_filter_component/preview
  def preview
    render(BuildResultsFilterComponent.new(package_names: DATA[:package_names],
                                           repository_names: DATA[:repository_names],
                                           architecture_names: DATA[:architecture_names],
                                           status_names: DATA[:status_names],
                                           filter_url: 'whatnot',
                                           filters: SELECTED_FITLERS))
  end
end
