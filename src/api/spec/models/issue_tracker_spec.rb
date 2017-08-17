require 'rails_helper'
require 'webmock/rspec'

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

  describe '#update_issues_github' do
    let!(:issue_tracker) { create(:issue_tracker, enable_fetch: true, url: 'http://api.a-fake-url.com/repos/openSUSE/open-build-service/issues') }
    let!(:issue) do
      # This line is necessary to prevent the issue after_create method from querying github
      allow_any_instance_of(Issue).to receive(:fetch_issues)
      create(:issue, name: '3628', issue_tracker: issue_tracker)
    end

    context 'with a 200 response from github' do
      include_context 'a github issue response'

      before do
        stub_request(:get, /api.a-fake-url.com*/).to_return(body: github_issues_json, status: 200)
      end

      subject! do
        issue_tracker.update_issues_github
      end

      it 'updates issue' do
        issue.reload
        expect(issue.summary).to eq('[ci] Trying fix flickering test in test_helper')
      end
    end

    context 'with a 404 response from github' do
      before do
        stub_request(:get, /api.a-fake-url.com*/).to_return(status: 404)
      end

      subject! do
        issue_tracker.update_issues_github
      end

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end
end
