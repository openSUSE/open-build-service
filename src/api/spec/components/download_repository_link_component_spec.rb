require 'rails_helper'

RSpec.describe DownloadRepositoryLinkComponent, type: :component do
  let(:project) { create(:project, name: 'home:Admin') }
  let(:repository) { create(:repository, project: project, name: 'images') }
  let(:configuration) { { 'download_url' => 'https://download.opensuse.org' } }

  context 'when published artifacts exist for the repository' do
    before do
      stub_request(:get, "#{CONFIG['source_url']}/published/#{project.name}/#{repository.name}")
        .to_return(body: '<directory><entry name="foo.rpm" /></directory>')
      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    it 'renders the download repository link' do
      expect(rendered_content).to have_link('Go to download repository', href: 'https://download.opensuse.org/home:/Admin/images')
    end
  end

  context 'when no published artifacts exist for the repository' do
    before do
      stub_request(:get, "#{CONFIG['source_url']}/published/#{project.name}/#{repository.name}")
        .to_return(body: '<directory/>')
      render_inline(described_class.new(project: project, repository: repository, configuration: configuration))
    end

    it 'renders nothing and hides the link' do
      expect(rendered_content).to have_no_link('Go to download repository')
    end
  end
end
