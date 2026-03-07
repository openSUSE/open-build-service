RSpec.describe SyncLocalPackageVersionJob, :vcr do
  describe '#perform' do
    let(:project_name) { 'openSUSE:Factory' }
    let(:package_name) { 'erlang' }

    # Use lazy `let` (not `let!`) so we can set up mocks before factory creation.
    # Creating a project with anitya_distribution_name triggers sync_local_package_version
    # via an after_save callback, which fires SyncLocalPackageVersionJob inline. We must
    # mock Backend::Connection.get before that happens or CI will try to reach backend:5352.
    #
    # Backend::Connection.get returns a Net::HTTPResponse, so the mock must respond to .body.
    let(:project) { create(:project, name: project_name, anitya_distribution_name: 'openSUSE') }
    let(:package) { create(:package, name: package_name, project: project) }

    context 'when fetching for a specific (linked) package' do
      let(:http_response) { instance_double(Net::HTTPResponse, body: '<sourceinfo package="erlang"><version>26.2.2</version></sourceinfo>') }

      before do
        allow(Backend::Connection).to receive(:get).and_return(http_response)
        package # force lazy evaluation after mock is in place
      end

      it 'updates the package version, reflecting the expanded link' do
        described_class.perform_now(project_name, package_name: package_name)

        expect(package.latest_local_version.version).to eq('26.2.2')
      end
    end

    context 'when fetching for an entire project' do
      let(:http_response) do
        instance_double(Net::HTTPResponse,
                        body: '<sourceinfolist><sourceinfo package="erlang"><version>26.2.2</version></sourceinfo></sourceinfolist>')
      end

      before do
        allow(Backend::Connection).to receive(:get).and_return(http_response)
        package # force lazy evaluation after mock is in place
      end

      it 'updates all package versions in the project' do
        described_class.perform_now(project_name)

        expect(package.latest_local_version.version).to eq('26.2.2')
      end
    end
  end
end
