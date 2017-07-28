require 'rails_helper'

RSpec.describe IssueTracker do
  describe '.write_to_backend' do
    subject { IssueTracker.write_to_backend }

    it 'queues a job' do
      expect { subject }.to have_enqueued_job(IssueTrackerWriteToBackendJob)
    end
  end

  describe '.update_all_issues' do
    let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true) }

    subject { IssueTracker.update_all_issues }

    it 'queues a job' do
      expect { subject }.to have_enqueued_job(IssueTrackerUpdateIssuesJob).with(issue_tracker.id)
    end
  end
end
