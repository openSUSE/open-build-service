require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe IssueTrackerWriteToBackendJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true, url: 'https://github.com/opensuse/issues') }
    let!(:issue) { create(:issue, name: '123', issue_tracker_id: issue_tracker.id, created_at: 4.days.ago) }

    before do
      allow(Backend::Connection).to receive(:put_source)
    end

    subject! { IssueTrackerWriteToBackendJob.new.perform }

    it 'writes to the backend' do
      expect(Backend::Connection).to have_received(:put_source)
    end
  end
end
