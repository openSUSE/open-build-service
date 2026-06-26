RSpec.describe SyncUpstreamPackageVersionJob, :vcr do
  describe '#perform' do
    let!(:project) { create(:project_with_package, name: 'factory', package_name: 'hello') }
    let(:package) { project.packages.first }
    let(:sync_time) { Time.zone.parse('2026-02-27 10:00:00') }

    before do
      # The project should exist in the Backend before we set anitya_distribution_name
      # This update call triggers the job because of the change of the anitya_distribution_name field value
      project.update(anitya_distribution_name: 'openSUSE')
    end

    context 'when the package is available upstream' do
      context 'providing a project name' do
        before do
          travel_to sync_time do
            described_class.perform_now(project_name: project.name)
          end
        end

        it 'creates a package version upstream record for the projects packages' do
          expect(PackageVersionUpstream.count).to eq(1)
          expect(package.package_versions.first).to have_attributes(version: '2.12.2', type: 'PackageVersionUpstream')
        end

        it 'updates the anitya distribution synced at column on the project' do
          expect(project.reload.anitya_distribution_synced_at).to eq(sync_time)
        end
      end

      context 'not providing a project name' do
        let!(:another_project) { create(:project_with_package, name: 'games', package_name: '0ad') }
        let(:another_package) { another_project.packages.first }

        before do
          # The project should exist in the Backend before we set anitya_distribution_name (what triggers the fetching jobs)
          another_project.update(anitya_distribution_name: 'openSUSE')
          travel_to sync_time do
            described_class.perform_now
          end
        end

        it 'creates a package version upstream record for all projects packages with the attribute assigned' do
          expect(PackageVersionUpstream.all).to contain_exactly(have_attributes(version: '0.28.0', type: 'PackageVersionUpstream'), have_attributes(version: '2.12.2', type: 'PackageVersionUpstream'))
        end

        it 'updates the anitya distribution synced at column on the project' do
          expect(project.reload.anitya_distribution_synced_at).to eq(sync_time)
        end
      end
    end

    context "when can't find the package upstream" do
      before do
        stub_request(:get, 'https://release-monitoring.org/api/v2/packages/')
          .with(query: { name: 'hello', distribution: 'openSUSE' })
          .to_return_json(
            status: 200,
            body: '{"items":[],"items_per_page":25,"page":1,"total_items":0}'
          )
      end

      context 'not providing a project name' do
        it 'removes the existing upstream versions' do
          expect { described_class.perform_now }.to change(PackageVersionUpstream, :count).from(1).to(0)
        end

        it 'does not update the anitya distribution synced at column on the project' do
          expect { described_class.perform_now }.not_to change(project, :anitya_distribution_synced_at)
        end
      end
    end
  end
end
