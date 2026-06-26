class BuildresultStatusLinkComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/buildresult_status_link_component/with_live_log_available
  def with_live_log_available
    render(BuildresultStatusLinkComponent.new(repository_name: 'openSUSE_Tumbleweed', architecture_name: 'x86_64',
                                              project_name: 'home:foo', package_name: 'hello_world',
                                              build_status: 'succeeded', build_details: ''))
  end

  # Preview at http://HOST:PORT/rails/view_components/buildresult_status_link_component/without_live_log
  def without_live_log
    render(BuildresultStatusLinkComponent.new(repository_name: 'openSUSE_Tumbleweed', architecture_name: 'x86_64',
                                              project_name: 'home:foo', package_name: 'hello_world',
                                              build_status: 'blocked', build_details: ''))
  end

  # Preview at http://HOST:PORT/rails/view_components/buildresult_status_link_component/with_build_constraints
  def with_build_constraints
    render(BuildresultStatusLinkComponent.new(repository_name: 'openSUSE_Tumbleweed', architecture_name: 'x86_64',
                                              project_name: 'home:foo', package_name: 'hello_world',
                                              build_status: 'scheduled', build_details: 'some details'))
  end
end
