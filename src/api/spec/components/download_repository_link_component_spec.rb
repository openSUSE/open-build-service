RSpec.describe DownloadRepositoryLinkComponent, type: :component do
  let(:project) { create(:project, name: 'home:Admin') }
  let(:repository) { create(:repository, project: project, name: 'images') }
  let(:configuration) { {} }

  def mock_download_url_for_repository(return_value: nil, raise_error: nil)
    if raise_error
      allow(Backend::Api::Published).to receive(:download_url_for_repository).and_raise(raise_error)
    else
      allow(Backend::Api::Published).to receive(:download_url_for_repository).and_return(return_value)
    end
  end

  shared_examples 'hides the download link' do
    it 'renders nothing and hides the link' do
      expect(rendered_content).to have_no_link('Go to download repository')
    end
  end

  context 'when the backend returns a download URL for the repository' do
    let(:published_xml) { '<published><url>https://download.opensuse.org/repositories/home:/Admin/images</url></published>' }

    before do
      mock_download_url_for_repository(return_value: published_xml)
      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    it 'renders the download repository link with the URL from the backend' do
      expect(rendered_content).to have_link('Go to download repository',
                                            href: 'https://download.opensuse.org/repositories/home:/Admin/images')
    end

    it 'calls the backend with the correct project and repository names' do
      expect(Backend::Api::Published).to have_received(:download_url_for_repository).with('home:Admin', 'images')
    end
  end

  context 'when the backend returns no URL for the repository' do
    before do
      mock_download_url_for_repository(return_value: '<published></published>')
      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    include_examples 'hides the download link'
  end

  context 'when the published repository does not exist on the backend' do
    before do
      mock_download_url_for_repository(raise_error: Backend::NotFoundError)
      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    include_examples 'hides the download link'
  end

  context 'when the backend raises an error' do
    before do
      mock_download_url_for_repository(raise_error: Backend::Error)
      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    include_examples 'hides the download link'
  end
end
