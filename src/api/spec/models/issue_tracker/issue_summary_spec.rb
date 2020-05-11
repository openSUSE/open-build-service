require 'rails_helper'

RSpec.describe IssueTracker::IssueSummary do
  let(:issue_tracker) { create(:issue_tracker) }
  let(:issue_tracker_instance) { IssueTracker::IssueSummary.new(issue_tracker.name, issue_id) }

  describe '#belongs_bug_to_tracker?' do
    context 'CVE ids' do
      let(:issue_tracker) { create(:issue_tracker, regex: '(?:cve|CVE)-(\\d\\d\\d\\d-\\d+)') }

      context 'with a valid issue id' do
        let(:issue_id) { 'CVE-3133-7' }

        it { expect(issue_tracker_instance).to be_belongs_bug_to_tracker }
      end

      context 'with an invalid issue id' do
        let(:issue_id) { 'CVE-A31337' }

        it { expect(issue_tracker_instance).not_to be_belongs_bug_to_tracker }
      end
    end

    context 'rest of the ids' do
      context 'with a valid issue id' do
        let(:issue_id) { '31337' }

        it { expect(issue_tracker_instance).to be_belongs_bug_to_tracker }
      end

      context 'with an invalid issue id' do
        let(:issue_id) { 'A31337' }

        it { expect(issue_tracker_instance).not_to be_belongs_bug_to_tracker }
      end
    end
  end
end
