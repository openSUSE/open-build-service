require 'webmock/rspec'

RSpec.describe IssueTrackerFetchIssuesJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:issue_tracker) { double(:issue_tracker, id: 1) }

    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
      allow(issue_tracker).to receive(:fetch_issues)

      IssueTrackerFetchIssuesJob.new.perform(issue_tracker.id)
    end

    it 'fetches the issues' do
      expect(issue_tracker).to have_received(:fetch_issues)
    end
  end
end
