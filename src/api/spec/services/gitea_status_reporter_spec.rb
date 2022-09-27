require 'rails_helper'

RSpec.describe GiteaStatusReporter, type: :service do
  let(:scm_status_reporter) { GiteaStatusReporter.new(event_payload, event_subscription_payload, token, state, workflow_run, initial_report: initial_report) }

  describe '.new' do
    context 'status pending when event_type is missing' do
      let(:event_payload) { {} }
      let(:event_subscription_payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }
      let(:state) { 'pending' }
      let(:workflow_run) { nil }
      let(:initial_report) { false }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('pending') }
    end

    context 'status failed on gitea' do
      let(:event_payload) { { project: 'home:john_doe', package: 'hello', repository: 'openSUSE_Tumbleweed', arch: 'i586' } }
      let(:event_subscription_payload) { { scm: 'gitea' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }
      let(:state) { 'failure' }
      let(:workflow_run) { nil }
      let(:initial_report) { false }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failure') }
    end
  end

  describe '#call' do
    context 'when sending a report back to Gitea' do
      let(:event_payload) do
        { project: 'home:danidoni', package: 'hello_world',
          repository: 'openSUSE_Tumbleweed', arch: 'x86_64' }
      end
      let(:event_subscription_payload) do
        { scm: 'gitea', target_repository_full_name: 'danidoni/hello_world', commit_sha: '123456789' }
      end
      let(:token) { 'XYCABC' }
      let(:state) { 'pending' }
      let(:workflow_run) { nil }
      let(:initial_report) { false }
      let(:status_options) do
        {
          context: 'OBS: hello_world - openSUSE_Tumbleweed/x86_64',
          target_url: 'https://unconfigured.openbuildservice.org/package/show/home:danidoni/hello_world'
        }
      end
      let(:gitea_client) { instance_spy(GiteaAPI::V1::Client) }

      subject { scm_status_reporter.call }

      before do
        allow(GiteaAPI::V1::Client).to receive(:new).and_return(gitea_client)
        subject
      end

      it 'sends a short commit sha' do
        expect(gitea_client).to have_received(:create_commit_status).with(owner: 'danidoni', repo: 'hello_world', sha: '123456789', state: state, **status_options)
      end
    end
  end
end
