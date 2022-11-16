class BuildResultForArchitectureComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/build_result_for_architecture_component/succeeded
  def succeeded
    result = LocalBuildResult.new(
      repository: '15.4',
      architecture: 'x86_64',
      code: 'succeeded',
      state: 'blocked',
      is_repository_in_db: 'true'
    )
    render(BuildResultForArchitectureComponent.new(result, 'fake_project', 'fake_package'))
  end

  # Preview at http://HOST:PORT/rails/view_components/build_result_for_architecture_component/broken
  def broken
    result = LocalBuildResult.new(
      repository: '15.4',
      architecture: 'x86_64',
      code: 'broken',
      state: 'published',
      is_repository_in_db: 'true',
      details: 'fake details'
    )
    render(BuildResultForArchitectureComponent.new(result, 'fake_project', 'fake_package'))
  end
end
