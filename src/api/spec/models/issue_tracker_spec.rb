require 'rails_helper'
require 'webmock/rspec'

RSpec.describe IssueTracker do
  describe '::update_all_issues' do
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
        expect(subject).to be_nil
      end
    end
  end

  describe '#fetch_issues' do
    context 'for an IssueTracker with kind == "bugzilla"' do
      let!(:issue_tracker) do
        create(
          :issue_tracker,
          kind: 'bugzilla',
          enable_fetch: true,
          url: 'http://api.a-fake-url.com/repos/openSUSE/open-build-service/issues'
        )
      end
      let!(:issue) do
        # This line is necessary to prevent the issue after_create method from querying github
        allow_any_instance_of(Issue).to receive(:fetch_issues)
        create(:issue, name: '3628', issue_tracker: issue_tracker)
      end
      let(:xmlrpc_client) { double(XMLRPC::Client, timeout: nil) }

      before do
        allow(XMLRPC::Client).to receive(:new2).and_return(xmlrpc_client)
        allow(xmlrpc_client).to receive(:timeout=)
        allow(xmlrpc_client).to receive(:user=)
        allow(xmlrpc_client).to receive(:password=)
        allow(xmlrpc_client).to receive(:proxy).and_return(xmlrpc_client)
        allow(xmlrpc_client).to receive(:get).and_raise(Errno::ECONNRESET)
      end

      subject! { issue_tracker.fetch_issues }

      it { is_expected.to be_falsey }
    end
  end
end
