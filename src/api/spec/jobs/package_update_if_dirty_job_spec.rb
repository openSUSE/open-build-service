require 'rails_helper'

RSpec.describe PackageUpdateIfDirtyJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:project) { create(:project, name: 'apache') }
    let!(:package) { create(:package_with_file, name: 'mod_ssl', project: project) }

    subject { PackageUpdateIfDirtyJob.new.perform(package.id) }

    it 'creates a BackendPackge for the Package' do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end
  end
end
