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

  describe '#parse_github_issue' do
    context 'with a valid response from github' do
      include_context 'a github issue response'

      let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true) }
      let!(:issue) { create(:issue, name: js['number'], issue_tracker: issue_tracker) }

      subject! { issue_tracker.send(:parse_github_issue, js) }

      it 'updates issue' do
        issue.reload
        expect(issue.summary).to eq(js['title'])
      end
    end

    context 'with an invalid response from github' do
      let(:js) { [] }
      let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true) }
      let!(:issue) { create(:issue, name: '123', issue_tracker: issue_tracker) }

      subject { issue_tracker.send(:parse_github_issue, js) }

      it 'raises TypeError' do
        expect{ subject }.to raise_error(TypeError)
      end
    end
  end
end
