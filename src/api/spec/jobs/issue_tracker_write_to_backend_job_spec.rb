RSpec.describe IssueTrackerWriteToBackendJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    subject { IssueTrackerWriteToBackendJob.new.perform }

    let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true, url: 'https://github.com/opensuse/issues') }
    let!(:issue) { travel_to(4.days.ago) { create(:issue, name: '123', issue_tracker_id: issue_tracker.id) } }
    let(:backend_response) { '<status code="ok" />' }

    before do
      stub_request(:put, "#{CONFIG['source_url']}/issue_trackers").and_return(body: backend_response)
    end

    it 'writes to the backend' do
      expect(subject).to eq(backend_response)
    end
  end
end
