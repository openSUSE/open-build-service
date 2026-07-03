class DownloadRepositoryLinkComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/download_repository_link_component/preview
  def preview
    view_component = DownloadRepositoryLinkComponent.new(project: Project.new(name: 'home:Admin'),
                                                         repository: Repository.new(name: 'openSUSE_Tumbleweed'),
                                                         configuration: { 'download_url' => 'https://download.opensuse.org' })
    # Set the generated URL explicitly because preview records do not exist in the published backend.
    view_component.instance_variable_set(:@download_area_url, 'https://download.opensuse.org/home:/Admin/openSUSE_Tumbleweed')

    render(view_component)
  end
end
