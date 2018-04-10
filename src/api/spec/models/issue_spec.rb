# frozen_string_literal: true
require 'rails_helper'

# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

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
