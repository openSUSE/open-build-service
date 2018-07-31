require 'rails_helper'

RSpec.describe IssueTracker::IssueSummary, vcr: true do
  let(:issue_tracker) { create(:issue_tracker) }
  let(:issue_tracker_instance) { IssueTracker::IssueSummary.new('github', '31337') }

  describe 'valid input' do
    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
    end

    it { expect(issue_tracker_instance).not_to be_nil }
    it { expect(issue_tracker_instance.bug).to eq("#{issue_tracker.name}#31337") }
    it { expect(issue_tracker_instance).to be_belongs_bug_to_tracker }
  end
end
