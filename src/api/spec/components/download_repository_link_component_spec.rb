RSpec.describe DownloadRepositoryLinkComponent, type: :component do
  let(:project) { create(:project, name: 'home:Admin') }
  let(:repository) { create(:repository, project: project, name: 'images') }
  let(:configuration) { { 'download_url' => 'https://download.opensuse.org' } }

  context 'when published artifacts exist for the repository' do
    before do
      allow(Backend::Api::Published).to receive(:published_repository_exist?).and_return(true)
      allow(Configuration).to receive(:download_url).and_return('https://download.example.com')
      render_inline(described_class.new(project: project, repository: repository))
    end

    it 'renders the download repository link' do
      expect(rendered_content).to have_link('Go to download repository', href: 'https://download.example.com/home:/Admin/images')
    end
  end

  context 'when no published artifacts exist for the repository' do
    before do
      allow(Backend::Api::Published).to receive(:published_repository_exist?).and_return(false)
      render_inline(described_class.new(project: project, repository: repository))
    end

    it 'renders text indicating no published packages' do
      expect(rendered_content).to have_text('There are no published packages')
      expect(rendered_content).to have_no_link('Go to download repository')
    end
  end
end
