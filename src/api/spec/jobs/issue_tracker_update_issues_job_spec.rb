RSpec.describe IssueTrackerUpdateIssuesJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:issue_tracker) { double(IssueTracker, id: 1) }

    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
      allow(issue_tracker).to receive(:update_issues)

      IssueTrackerUpdateIssuesJob.new.perform(issue_tracker.id)
    end

    it 'updates the issues' do
      expect(issue_tracker).to have_received(:update_issues)
    end
  end
end
