RSpec.describe SCMStatusReporter, type: :service do
  let(:scm_status_reporter) { SCMStatusReporter.new(event_payload: event_payload, event_subscription_payload: event_subscription_payload, scm_token: token, workflow_run: workflow_run, event_type: event_type) }

  describe '.new' do
    context 'status pending when event_type is missing' do
      subject { scm_status_reporter }

      let(:event_payload) { {} }
      let(:event_subscription_payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }
      let(:workflow_run) { nil }

      it { expect(subject.state).to eq('pending') }
    end
  end

  describe '.call' do
    context 'when responding to a request state change event' do
      subject { scm_status_reporter }

      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:event_payload) do
        Event::RequestStatechange.create!(
          eventtype: 'Event::RequestStatechange',
          author: 'Admin',
          comment: 'Revoke as https://github.com/danidoni/hello_world/pull/91 got closed',
          number: 35,
          state: 'revoked',
          when: '2023-07-28T13:43:02',
          who: 'Admin',
          namespace: 'home',
          oldstate: 'new',
          duration: 287
        ).payload
      end
      let(:event_subscription_payload) do
        EventSubscription.create(eventtype: 'Event::RequestStatechange',
                                 channel: :scm,
                                 receiver_role: 'Any role',
                                 payload: { scm: 'github',
                                            api_endpoint: 'https://api.github.com',
                                            event: 'pull_request',
                                            commit_sha: 'f3f93c179ad546728b5a74eef252896d28111ca6',
                                            pr_number: 92,
                                            source_branch: 'danidoni-patch-19',
                                            target_branch: 'master',
                                            action: 'new',
                                            source_repository_full_name: 'danidoni/hello_world',
                                            target_repository_full_name: 'danidoni/hello_world' },
                                 bs_request: bs_request).payload
      end
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::RequestStatechange' }
      let(:workflow_run) { create(:workflow_run) }
      let(:github_instance) { instance_spy(Octokit::Client, create_status: true) }

      before do
        allow(Octokit::Client).to receive(:new).and_return(github_instance)
      end

      it { expect(subject.state).to eq('failure') }
      it { expect { subject.call }.to change(SCMStatusReport, :count).by(1) }
    end
  end
end
