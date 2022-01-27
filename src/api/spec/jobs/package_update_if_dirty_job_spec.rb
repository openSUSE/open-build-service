require 'rails_helper'

# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe PackageUpdateIfDirtyJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:project) { create(:project, name: 'apache') }
    let(:changes_file) { file_fixture('mod_ssl.changes').read }
    let!(:package) { create(:package_with_changes_file, project: project, name: 'mod_ssl', changes_file_content: changes_file) }

    subject { PackageUpdateIfDirtyJob.new.perform(package.id) }

    # We have to enable the issue tracker first and update them
    # on the backend in order to make the test work
    before do
      # rubocop:disable Rails/SkipsModelValidations
      IssueTracker.update_all(enable_fetch: true)
      # rubocop:enable Rails/SkipsModelValidations
      IssueTrackerWriteToBackendJob.new.perform_now
    end

    it 'creates a BackendPackge for the Package' do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end

    it 'creates issues from the text in the changes file' do
      # The changes file contains: gh#cli/cli#1, CVE-2021-12345 and bsc#3
      expect { subject }.to change(Issue, :count).by(3)
    end
  end
end
