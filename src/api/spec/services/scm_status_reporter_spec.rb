require 'rails_helper'

RSpec.describe SCMStatusReporter, type: :service do
  let(:scm_status_reporter) { SCMStatusReporter.new(event_payload, event_subscription_payload, token, event_type) }

  describe '.new' do
    context 'status pending when event_type is missing' do
      let(:event_payload) { {} }
      let(:event_subscription_payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('pending') }
    end

    context 'status failed on github' do
      let(:event_payload) { { project: 'home:john_doe', package: 'hello', repository: 'openSUSE_Tumbleweed', arch: 'i586' } }
      let(:event_subscription_payload) { { scm: 'github' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failure') }
    end

    context 'status failed on gitlab' do
      let(:event_payload) { { project: 'home:jane_doe', package: 'bye', repository: 'openSUSE_Leap', arch: 'x86_64' } }
      let(:event_subscription_payload) { { scm: 'gitlab' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failed') }
    end
  end

  describe '#call' do
    context 'when sending a report back to SCM fails' do
      let(:scm_status_reporter) { SCMStatusReporter.new(event_payload, event_subscription_payload, token, event_type, workflow_run) }

      let!(:user) { create(:confirmed_user, :with_home, login: 'jane_doe') }
      let!(:package) { create(:package, name: 'bye', project: user.home_project) }

      let(:workflow_token) { create(:workflow_token, user: user) }
      let(:token) { workflow_token.scm_token }
      let(:workflow_run) { create(:workflow_run, token: workflow_token, request_headers: {}, request_payload: {}) }

      let(:event_payload) do
        { project: user.home_project_name, package: package.name, repository: 'openSUSE_Leap', arch: 'x86_64' }
      end

      let(:event_subscription_payload) { { scm: 'github' } }

      let(:event_type) { 'Event::BuildSuccess' }

      let!(:event_subscription) do
        EventSubscription.create(channel: 'scm', package: package, eventtype: event_type, receiver_role: 'reader', token: workflow_token, workflow_run: workflow_run)
      end

      let(:octokit_client) { Octokit::Client.new }

      subject { scm_status_reporter.call }

      context "repository doesn't exist" do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_raise(Octokit::InvalidRepository)
        end

        it { expect { subject }.to change(EventSubscription, :count).by(-1) }

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
          subject
        end

        it 'tracks the exception in the workflow_run response body and sets the status to fail' do
          expect(workflow_run.status).to eq('fail')
          expect(workflow_run.last_response_body).to eq('Failed to report back to GitHub: Sorry. Your account is suspended.')
        end
      end

      context 'there is a network glitch' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_raise(Faraday::ConnectionFailed.new('Network glitch'))
          subject
        end

        it 'tracks the exception in the workflow_run response body and sets the status to fail' do
          expect(workflow_run.status).to eq('fail')
          expect(workflow_run.response_body).to eq('Failed to report back to GitHub: Network glitch')
        end
      end
    end

    context 'when sending a report back to GitHub' do
      let(:event_payload) do
        { project: 'home:danidoni', package: 'hello_world',
          repository: 'openSUSE_Tumbleweed', arch: 'x86_64' }
      end
      let(:event_subscription_payload) do
        { scm: 'github', target_repository_full_name: 'danidoni/hello_world', commit_sha: '123456789' }
      end
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }
      let(:state) { 'pending' }
      let(:status_options) do
        {
          context: 'OBS: hello_world - openSUSE_Tumbleweed/x86_64',
          target_url: 'https://unconfigured.openbuildservice.org/package/show/home:danidoni/hello_world'
        }
      end
      let(:octokit_client) { instance_spy(Octokit::Client, create_status: true) }

      subject { scm_status_reporter.call }

      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        subject
      end

      it 'sends a short commit sha' do
        expect(octokit_client).to have_received(:create_status).with('danidoni/hello_world', '123456789', state, status_options)
      end
    end

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
      let(:status_options) do
        {
          context: 'OBS: hello_world - openSUSE_Tumbleweed/x86_64',
          target_url: 'https://unconfigured.openbuildservice.org/package/show/home:danidoni/hello_world'
        }
      end
      let(:gitlab_instance) { instance_spy('Client', update_commit_status: true) }

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
