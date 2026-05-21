RSpec.describe GithubStatusReporter, type: :service do
  let(:scm_status_reporter) { GithubStatusReporter.new(event_payload, event_subscription_payload, token, state, workflow_run, event_type, initial_report: initial_report) }
  let(:workflow_run) { create(:workflow_run, scm_vendor: 'github', request_payload: request_payload, token: create(:workflow_token, string: token)) }
  let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

  describe '.new' do
    context 'status pending when event_type is missing' do
      subject { scm_status_reporter }

      let(:event_payload) { {} }
      let(:event_subscription_payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }
      let(:state) { 'pending' }
      let(:initial_report) { false }

      it { expect(subject.state).to eq('pending') }
    end

    context 'status failed on github' do
      subject { scm_status_reporter }

      let(:event_payload) { { project: 'home:john_doe', package: 'hello', repository: 'openSUSE_Tumbleweed', arch: 'i586' } }
      let(:event_subscription_payload) { { scm: 'github' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }
      let(:state) { 'failure' }
      let(:initial_report) { false }

      it { expect(subject.state).to eq('failure') }
    end
  end

  describe '#call' do
    context 'when sending a report back to SCM fails' do
      subject { scm_status_reporter.call }

      let(:scm_status_reporter) { GithubStatusReporter.new(event_payload, event_subscription_payload, token, state, workflow_run, initial_report: false) }

      let!(:user) { create(:confirmed_user, :with_home, login: 'jane_doe') }
      let!(:package) { create(:package, name: 'bye', project: user.home_project) }

      let(:workflow_token) { create(:workflow_token, executor: user) }
      let(:token) { workflow_token.scm_token }
      let(:workflow_run) { create(:workflow_run, token: workflow_token, request_headers: {}, request_payload: {}) }

      let(:event_payload) do
        { project: user.home_project_name, package: package.name, repository: 'openSUSE_Leap', arch: 'x86_64' }
      end

      let(:event_subscription_payload) { { scm: 'github' } }
      let(:event_type) { 'Event::BuildSuccess' }
      let(:state) { 'success' }

      let!(:event_subscription) do
        EventSubscription.create(channel: 'scm', package: package, eventtype: event_type, receiver_role: 'reader', token: workflow_token, workflow_run: workflow_run)
      end

      let(:octokit_client) { Octokit::Client.new }

      context "repository doesn't exist" do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_raise(Octokit::InvalidRepository)
        end

        it { expect { subject }.to change(EventSubscription, :count).by(-1) }
        it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

        it 'tracks the exception in the workflow_run response body and sets the status to fail' do
          subject
          expect(workflow_run.status).to eq('fail')
          expect(workflow_run.last_response_body).to eq('Failed to report back to GitHub: Octokit::InvalidRepository')
        end
      end

      context 'scm exception handler rescues from exception' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_raise(Octokit::AccountSuspended)
        end

        it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

        it 'tracks the exception in the workflow_run response body and sets the status to fail' do
          subject
          expect(workflow_run.status).to eq('fail')
          expect(workflow_run.last_response_body).to eq('Failed to report back to GitHub: Sorry. Your account is suspended.')
        end
      end

      context 'there is a network glitch' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_raise(Faraday::ConnectionFailed.new('Network glitch'))
        end

        it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

        it 'tracks the exception in the workflow_run response body and sets the status to fail' do
          subject
          expect(workflow_run.status).to eq('fail')
          expect(workflow_run.last_response_body).to eq('Failed to report back to GitHub: Network glitch')
        end
      end
    end

    context 'when sending a report back to GitHub' do
      context 'when is an initial report' do
        subject { scm_status_reporter.call }

        let(:event_payload) do
          { project: 'home:danidoni', package: 'hello_world',
            repository: 'openSUSE_Tumbleweed', arch: 'x86_64' }
        end
        let(:event_subscription_payload) do
          { scm: 'github', target_repository_full_name: 'openSUSE/repo123', commit_sha: '123456789' }
        end
        let(:token) { 'XYCABC' }
        let(:event_type) { nil }
        let(:state) { 'pending' }
        let(:initial_report) { false }
        let(:expected_status_options) do
          {
            context: 'OBS: hello_world - openSUSE_Tumbleweed/x86_64',
            target_url: 'https://unconfigured.openbuildservice.org/package/show/home:danidoni/hello_world'
          }
        end
        let(:octokit_client) { instance_spy(Octokit::Client, create_status: true) }

        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          subject
        end

        it 'creates a commit status' do
          expect(octokit_client).to have_received(:create_status).with('openSUSE/repo123', '123456789', state, expected_status_options)
        end
      end

      context 'when reporting a submit request' do
        subject { scm_status_reporter.call }

        let(:event_payload) do
          { project: 'home:danidoni', package: 'hello_world',
            repository: 'openSUSE_Tumbleweed', arch: 'x86_64',
            number: 1, state: 'new' }
        end
        let(:event_subscription_payload) do
          { scm: 'github', target_repository_full_name: 'openSUSE/repo123', commit_sha: '123456789' }
        end
        let(:token) { 'XYCABC' }
        let(:event_type) { 'Event::RequestStatechange' }
        let(:state) { 'pending' }
        let(:initial_report) { false }
        let(:expected_status_options) do
          {
            context: 'OBS: Request 1',
            target_url: 'https://unconfigured.openbuildservice.org/request/show/1'
          }
        end
        let(:octokit_client) { instance_spy(Octokit::Client, create_status: true) }

        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          subject
        end

        it 'creates a commit status' do
          expect(octokit_client).to have_received(:create_status).with('openSUSE/repo123', '123456789', state, expected_status_options)
        end
      end
    end
  end
end
