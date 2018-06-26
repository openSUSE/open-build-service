require 'rails_helper'

RSpec.describe Issue, vcr: true do
  describe '#fetch_issues' do
    let!(:issue_tracker) { create(:issue_tracker) }
    let!(:issue) { create(:issue, issue_tracker: issue_tracker) }

    before do
      allow(IssueTracker).to receive(:find).and_return(issue_tracker)
      allow(issue_tracker).to receive(:fetch_issues)
    end

    subject! { issue.fetch_issues }

    it 'fetches the issues' do
      expect(issue_tracker).to have_received(:fetch_issues)
    end
  end
end
