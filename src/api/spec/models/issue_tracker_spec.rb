require 'rails_helper'

RSpec.describe IssueTracker do
  describe '.update_all_issues' do
    let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true) }

    before do
      allow(IssueTracker).to receive(:find).and_return(issue_tracker)
      allow(issue_tracker).to receive(:update_issues)
    end

    subject! { IssueTracker.update_all_issues }

    it 'updates the issues' do
      expect(issue_tracker).to have_received(:update_issues)
    end
  end
end
