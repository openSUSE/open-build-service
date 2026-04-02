RSpec.describe SyncLocalPackageVersionJob do
  describe '#perform' do
    let(:project_name) { 'openSUSE:Factory' }
    let(:package_name) { 'erlang' }

    context 'with existing project and package' do
      let(:project) do
        # Create without anitya_distribution_name first to avoid triggering the job on save
        p = create(:project, name: project_name)
        p.update_column(:anitya_distribution_name, 'openSUSE')
        p
      end
      let(:package) { create(:package, name: package_name, project: project) }

      context 'when fetching for a specific (linked) package' do
        it 'updates the package version', vcr: { cassette_name: 'jobs/sync_erlang_expanded' } do
          described_class.perform_now(project_name, package_name: package_name)
          expect(package.reload.latest_local_version.version).to eq('26.2.2')
        end
      end
    end
  end
end
