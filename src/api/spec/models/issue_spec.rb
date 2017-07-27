require 'rails_helper'

RSpec.describe Issue, vcr: true do
  describe '#fetch_issues' do
    let!(:issue_tracker) { create(:issue_tracker) }
    let!(:issue) { create(:issue, issue_tracker: issue_tracker) }

    subject { issue.fetch_issues }

    it do
      expect { subject }.to have_enqueued_job(IssueTrackerFetchIssuesJob).with(issue_tracker.id)
    end
  end
end
