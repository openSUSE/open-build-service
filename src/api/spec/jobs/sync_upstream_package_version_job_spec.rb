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

  describe 'retrying network errors', vcr: false do
    include ActiveJob::TestHelper

    let!(:project) { create(:project_with_package, name: 'factory', package_name: 'hello') }
    let(:job) { described_class.new(project_name: project.name) }
    let(:upstream_request) { stub_request(:get, 'https://release-monitoring.org/api/v2/packages/?name=hello&distribution=openSUSE') }

    around do |example|
      previous_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = previous_adapter
    end

    before do
      allow(Project).to receive(:values_for_anitya_distributions).and_return(['openSUSE'])
      project.update!(anitya_distribution_name: 'openSUSE')
      clear_enqueued_jobs
    end

    [Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, EOFError].each do |error_class|
      it "retries #{error_class} with the same project" do
        upstream_request.to_raise(error_class)

        expect { job.perform_now }.to have_enqueued_job(described_class).with(project_name: project.name)
        expect(project.reload.anitya_distribution_synced_at).to be_nil
      end
    end

    it 'waits longer after another failed attempt' do
      upstream_request.to_raise(Errno::ECONNRESET)
      job.perform_now

      freeze_time do
        expect { job.perform_now }.to have_enqueued_job(described_class).at(1.minute.from_now)
      end
    end

    it 'syncs the upstream version when a retry succeeds' do
      upstream_request.to_raise(Errno::ECONNRESET).then.to_return_json(body: { total_items: 1, items: [{ stable_version: '2.12.2' }] })
      job.perform_now

      perform_enqueued_jobs(only: described_class)

      expect(project.packages.first.package_versions.find_by(type: 'PackageVersionUpstream').version).to eq('2.12.2')
      expect(project.reload.anitya_distribution_synced_at).to be_present
    end

    it 'raises the error after all attempts are exhausted' do
      upstream_request.to_raise(Errno::ECONNRESET)
      5.times { job.perform_now }
      clear_enqueued_jobs

      expect { job.perform_now }.to raise_error(Errno::ECONNRESET)
      expect(enqueued_jobs).to be_empty
    end

    it 'does not retry certificate errors' do
      upstream_request.to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))

      expect { job.perform_now }.to raise_error(OpenSSL::SSL::SSLError, 'certificate verify failed')
      expect(enqueued_jobs).to be_empty
    end
  end
end
