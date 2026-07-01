class DownloadRepositoryLinkComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/download_repository_link_component/preview
  def preview
    view_component = DownloadRepositoryLinkComponent.new(project: Project.new(name: 'home:Admin'),
                                                         repository: Repository.new(name: 'openSUSE_Tumbleweed'),
                                                         configuration: {})
    # Bypass the backend call for preview purposes since the project and repository don't exist.
    view_component.instance_variable_set(:@download_area_url, 'https://download.opensuse.org/repositories/home:/Admin/openSUSE_Tumbleweed')

    render(view_component)
  end
end
