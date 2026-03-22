RSpec.describe SyncLocalPackageVersionJob do
  describe '#perform' do
    let(:project_name) { 'openSUSE:Factory' }
    let(:package_name) { 'erlang' }

    before do
      allow(Backend::Api::Sources::Package).to receive(:files).and_return(
        '<sourceinfo package="erlang"><version>26.2.2</version></sourceinfo>'
      )
      allow(Backend::Api::Sources::Project).to receive(:packages).and_return(
        '<sourceinfolist><sourceinfo package="erlang"><version>26.2.2</version></sourceinfo></sourceinfolist>'
      )
    end

    context 'with existing project and package' do
      # Creating a project with anitya_distribution_name triggers sync_local_package_version
      # via an after_save callback, which fires SyncLocalPackageVersionJob inline.
      # The mocks above must be set up before these let! calls are evaluated.
      let!(:project) { create(:project, name: project_name, anitya_distribution_name: 'openSUSE') }
      let!(:package) { create(:package, name: package_name, project: project) }

      context 'when fetching for a specific (linked) package' do
        it 'updates the package version, reflecting the expanded link' do
          described_class.perform_now(project_name, package_name: package_name)

          expect(package.reload.latest_local_version.version).to eq('26.2.2')
        end
      end

      context 'when fetching for an entire project' do
        it 'updates all package versions in the project' do
          described_class.perform_now(project_name)

          expect(package.reload.latest_local_version.version).to eq('26.2.2')
        end
      end
    end
  end
end
