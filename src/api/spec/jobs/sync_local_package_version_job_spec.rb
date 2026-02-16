require 'webmock/rspec'

RSpec.describe SyncLocalPackageVersionJob do
  describe '#perform' do
    before do
      WebMock.disable_net_connect!(allow_localhost: false)
      VCR.configure { |c| c.ignore_localhost = false }
      stub_request(:any, /.*/).to_return(status: 200, body: '<sourceinfo package="erlang"><version>26.2.2</version></sourceinfo>')
    end

    let(:project_name) { 'openSUSE:Factory' }
    let(:package_name) { 'erlang' }
    let!(:project) { create(:project, name: project_name, anitya_distribution_name: 'openSUSE') }
    let!(:package) { create(:package, name: package_name, project: project) }
    let(:source_url) { CONFIG['source_url'] }

    after do
      VCR.configure { |c| c.ignore_localhost = true }
      WebMock.disable_net_connect!(allow_localhost: true)
    end

    context 'when fetching for a specific package' do
      let(:response_body) { '<sourceinfo package="erlang"><version>26.2.2</version></sourceinfo>' }

      it 'calls the backend with expand: 1' do
        stub_request(:get, %r{/source/openSUSE%3AFactory/#{package_name}})
          .with(query: hash_including('expand' => '1')).to_return(body: response_body)
        expect { described_class.perform_now(project_name, package_name: package_name) }
          .to change(PackageVersionLocal, :count).by(1)
        expect(package.latest_local_version.version).to eq('26.2.2')
      end
    end

    context 'when fetching for an entire project' do
      let(:response_body) { '<directory><sourceinfo package="erlang"><version>26.2.2</version></sourceinfo></directory>' }

      it 'calls the backend with expand: 1' do
        stub_request(:get, %r{/source/openSUSE%3AFactory})
          .with(query: hash_including('expand' => '1')).to_return(body: response_body)
        expect { described_class.perform_now(project_name) }.to change(PackageVersionLocal, :count).by(1)
        expect(package.latest_local_version.version).to eq('26.2.2')
      end
    end
  end
end
