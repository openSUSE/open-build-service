RSpec.describe GitlabStatusReporter, type: :service do
  let(:scm_status_reporter) { GitlabStatusReporter.new(event_payload, event_subscription_payload, token, state, workflow_run, event_type, initial_report: initial_report) }
  let(:workflow_run) { create(:workflow_run_gitlab, request_payload: request_payload, token: create(:workflow_token, string: token)) }
  let(:request_payload) { file_fixture('request_payload_gitlab_pull_request_opened.json').read }

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

    context 'status failed on gitlab' do
      subject { scm_status_reporter }

      let(:event_payload) { { project: 'home:jane_doe', package: 'bye', repository: 'openSUSE_Leap', arch: 'x86_64' } }
      let(:event_subscription_payload) { { scm: 'gitlab' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }
      let(:state) { 'failed' }
      let(:initial_report) { false }

      it { expect(subject.state).to eq('failed') }
    end
  end

  describe '#call' do
    context 'when sending a report back to GitLab' do
      subject { scm_status_reporter.call }

      let(:event_payload) do
        { project: 'home:danidoni', package: 'hello_world',
          repository: 'openSUSE_Tumbleweed', arch: 'x86_64' }
      end
      let(:event_subscription_payload) do
        { scm: 'gitlab', project_id: '26_212_710', commit_sha: '123456789' }
      end
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }
      let(:state) { 'pending' }
      let(:initial_report) { false }
      let(:status_options) do
        {
          context: 'OBS: hello_world - openSUSE_Tumbleweed/x86_64',
          target_url: 'https://unconfigured.openbuildservice.org/package/show/home:danidoni/hello_world'
        }
      end
      let(:gitlab_instance) { instance_spy(Gitlab::Client, update_commit_status: true) }

      before do
        allow(Gitlab).to receive(:client).and_return(gitlab_instance)
        subject
      end

      it 'sends a short commit sha' do
        expect(gitlab_instance).to have_received(:update_commit_status).with('26_212_710', '123456789', state, status_options)
      end
    end

    context 'when reporting a submit request' do
      subject { scm_status_reporter.call }

      let(:request_payload) { file_fixture('request_payload_gitlab_pull_request_opened.json').read }

      let(:event_payload) do
        { project: 'home:danidoni', package: 'hello_world',
          repository: 'openSUSE_Tumbleweed', arch: 'x86_64',
          number: 1, state: 'new' }
      end
      let(:event_subscription_payload) do
        { scm: 'gitlab', project_id: '26_212_710', commit_sha: '123456789' }
      end
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::RequestStatechange' }
      let(:state) { 'pending' }
      let(:initial_report) { false }
      let(:status_options) do
        {
          context: 'OBS: Request 1',
          target_url: 'https://unconfigured.openbuildservice.org/request/show/1'
        }
      end
      let(:gitlab_instance) { instance_spy(Gitlab::Client, update_commit_status: true) }

      before do
        allow(Gitlab).to receive(:client).and_return(gitlab_instance)
        subject
      end

      it 'creates a commit status' do
        expect(gitlab_instance).to have_received(:update_commit_status).with('26_212_710', '123456789', state, status_options)
      end
    end

    context 'when GitLab responds with 401 Unauthorized (token expired)' do
      subject { scm_status_reporter.call }

      let(:event_payload) { { project: 'home:user', package: 'pkg', repository: 'repo', arch: 'x86_64' } }
      let(:event_subscription_payload) { { scm: 'gitlab', project_id: '123', commit_sha: 'abc' } }
      let(:token) { 'EXPIRED' }
      let(:event_type) { nil }
      let(:state) { 'pending' }
      let(:initial_report) { false }
      let(:gitlab_instance) { instance_spy(Gitlab::Client) }
      let(:exception) do
        e = Gitlab::Error::Unauthorized.allocate
        allow(e).to receive_messages(message: 'Token is expired', response_message: 'Token is expired')
        e
      end

      before do
        allow(Gitlab).to receive(:client).and_return(gitlab_instance)
        allow(gitlab_instance).to receive(:update_commit_status).and_raise(exception)
        allow(scm_status_reporter.instance_variable_get(:@workflow_run)).to receive(:save_scm_report_failure)
      end

      it 'handles the exception by marking workflow_run as failed without re-raising', :aggregate_failures do
        expect { subject }.not_to raise_error
        expect(scm_status_reporter.instance_variable_get(:@workflow_run)).to have_received(:save_scm_report_failure).with(/Token is expired/, anything)
      end
    end

    context 'when GitLab responds with 401 Unauthorized (regular auth failure)' do
      subject { scm_status_reporter.call }

      let(:event_payload) { { project: 'home:user', package: 'pkg', repository: 'repo', arch: 'x86_64' } }
      let(:event_subscription_payload) { { scm: 'gitlab', project_id: '123', commit_sha: 'abc' } }
      let(:token) { 'INVALID' }
      let(:event_type) { nil }
      let(:state) { 'pending' }
      let(:initial_report) { false }
      let(:gitlab_instance) { instance_spy(Gitlab::Client) }
      let(:exception) do
        e = Gitlab::Error::Unauthorized.allocate
        allow(e).to receive_messages(message: 'Unauthorized request.', response_message: 'Unauthorized request.')
        e
      end

      before do
        allow(Gitlab).to receive(:client).and_return(gitlab_instance)
        allow(gitlab_instance).to receive(:update_commit_status).and_raise(exception)
      end

      it 're-raises the exception for the retry loop' do
        expect { subject }.to raise_error(Gitlab::Error::Unauthorized, /Unauthorized request/)
      end
    end
  end
end
