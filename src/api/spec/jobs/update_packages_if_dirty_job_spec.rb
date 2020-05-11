require 'rails_helper'

# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe UpdatePackagesIfDirtyJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    context 'the project is found' do
      let!(:project) { create(:project, name: 'apache') }
      let!(:package) { create(:package_with_file, project: project, name: 'mod_ssl') }

      subject { UpdatePackagesIfDirtyJob.new.perform(project.id) }

      it 'creates a BackendPackge for the Package' do
        expect { subject }.to change(BackendPackage, :count).by(1)
      end
    end

    context 'the project is not found' do
      subject { UpdatePackagesIfDirtyJob.new.perform(123) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
