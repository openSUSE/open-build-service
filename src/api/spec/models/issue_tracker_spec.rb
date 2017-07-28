require 'rails_helper'

RSpec.describe IssueTracker do
  describe '.write_to_backend' do
    subject { IssueTracker.write_to_backend }

    it 'queues a job' do
      expect { subject }.to have_enqueued_job(IssueTrackerWriteToBackendJob)
    end
  end
end
