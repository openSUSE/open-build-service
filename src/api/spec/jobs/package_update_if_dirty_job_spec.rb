RSpec.describe PackageUpdateIfDirtyJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    subject { PackageUpdateIfDirtyJob.new.perform(package.id) }

    let!(:project) { create(:project, name: 'apache') }
    let!(:package) { create(:package_with_file, name: 'mod_ssl', project: project) }

    it 'creates a BackendPackge for the Package' do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end
  end
end
