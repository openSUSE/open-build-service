RSpec.describe DownloadRepositoryLinkComponent, type: :component do
  let(:project) { create(:project, name: 'home:Admin') }
  let(:repository) { create(:repository, project: project, name: 'images') }
  let(:configuration) { { 'download_url' => 'https://download.opensuse.org/repositories' } }

  def mock_published_repository_exist(return_value: nil, raise_error: nil)
    if raise_error
      allow(Backend::Api::Published).to receive(:published_repository_exist?).and_raise(raise_error)
    else
      allow(Backend::Api::Published).to receive(:published_repository_exist?).and_return(return_value)
    end
  end

  shared_examples 'hides the download link' do
    it 'renders nothing and hides the link' do
      expect(rendered_content).to have_no_link('Go to download repository')
    end
  end

  context 'when published artifacts exist for the repository' do
    before do
      mock_published_repository_exist(return_value: true)

      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    it 'renders the download repository link' do
      expect(rendered_content).to have_link('Go to download repository', href: 'https://download.opensuse.org/repositories/home:/Admin/images')
    end

    it 'calls the backend with the correct project and repository names' do
      expect(Backend::Api::Published).to have_received(:published_repository_exist?).with('home:Admin', 'images')
    end
  end

  context 'when no published artifacts exist for the repository' do
    before do
      mock_published_repository_exist(return_value: false)

      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    include_examples 'hides the download link'
  end

  context 'when the published repository is missing' do
    before do
      mock_published_repository_exist(raise_error: Backend::NotFoundError)

      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    include_examples 'hides the download link'
  end
end
