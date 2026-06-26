class DownloadRepositoryLinkComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/download_repository_link_component/preview
  def preview
    view_component = DownloadRepositoryLinkComponent.new(project: Project.new(name: 'home:Admin'),
                                                         repository: Repository.new(name: 'openSUSE_Tumbleweed'),
                                                         configuration: { 'download_url' => 'https://download.opensuse.org' })
    # Just to make sure that the link is displayed, since the repository won't be published if the project and repository don't exist.
    view_component.instance_variable_set(:@published_repository_exist, true)

    render(view_component)
  end
end
