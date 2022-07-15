require 'rails_helper'

RSpec.describe GitlabStatusReporter, type: :service do
  let(:scm_status_reporter) { GitlabStatusReporter.new(event_payload, event_subscription_payload, token, state, workflow_run, initial_report: initial_report) }

  describe '.new' do
    context 'status pending when event_type is missing' do
      let(:event_payload) { {} }
      let(:event_subscription_payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }
      let(:workflow_run) { nil }
      let(:state) { 'pending' }
      let(:initial_report) { false }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('pending') }
    end

    context 'status failed on gitlab' do
      let(:event_payload) { { project: 'home:jane_doe', package: 'bye', repository: 'openSUSE_Leap', arch: 'x86_64' } }
      let(:event_subscription_payload) { { scm: 'gitlab' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }
      let(:workflow_run) { nil }
      let(:state) { 'failed' }
      let(:initial_report) { false }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failed') }
    end
  end

  describe '#call' do
    context 'when sending a report back to GitLab' do
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
      let(:workflow_run) { nil }
      let(:initial_report) { false }
      let(:status_options) do
        {
          context: 'OBS: hello_world - openSUSE_Tumbleweed/x86_64',
          target_url: 'https://unconfigured.openbuildservice.org/package/show/home:danidoni/hello_world'
        }
      end
      let(:gitlab_instance) { instance_spy(Gitlab::Client, update_commit_status: true) }

      subject { scm_status_reporter.call }

      before do
        allow(Gitlab).to receive(:client).and_return(gitlab_instance)
        subject
      end

      it 'sends a short commit sha' do
        expect(gitlab_instance).to have_received(:update_commit_status).with('26_212_710', '123456789', state, status_options)
      end
    end
  end
end
