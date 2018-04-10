# frozen_string_literal: true
require 'rails_helper'

RSpec.describe IssueTrackerUpdateIssuesJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:issue_tracker) { double(IssueTracker, id: 1) }

    before do
      allow(IssueTracker).to receive(:find).and_return(issue_tracker)
      allow(issue_tracker).to receive(:update_issues)
    end

    subject! { IssueTrackerUpdateIssuesJob.new.perform(issue_tracker.id) }

    it 'updates the issues' do
      expect(issue_tracker).to have_received(:update_issues)
    end
  end
end
