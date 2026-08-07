RSpec.describe ReportToSCMJob do
  let(:user) { create(:confirmed_user, login: 'foolano') }
  let(:token) { Token::Workflow.create(executor: user, scm_token: 'fake_token') }
  let(:project) { create(:project, name: 'project_1', maintainer: user) }
  let(:package) { create(:package, name: 'package_1', project: project) }
  let(:repository) { create(:repository, name: 'repository_1', project: project) }
  let(:event) { Event::BuildSuccess.create({ project: project.name, package: package.name, repository: repository.name, reason: 'foo' }) }
  let(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }
  let(:event_subscription) do
    EventSubscription.create(token: token,
                             user: user,
                             package: package,
                             receiver_role: 'reader',
                             payload: { scm: 'github' },
                             eventtype: 'Event::BuildSuccess',
                             channel: :scm,
                             workflow_run_id: workflow_run.id)
  end

  shared_examples 'not reporting to the SCM' do
    it 'does not call the scm reporter' do
      expect_any_instance_of(GithubStatusReporter).not_to receive(:call) # rubocop:disable RSpec/AnyInstance
      subject
    end
  end

  describe '#perform' do
    subject { described_class.perform_now(event_id: event.id) }

    context 'happy path' do
      before do
        event
        event_subscription
      end

      it 'does call the scm reporter' do
        allow_any_instance_of(Octokit::Client).to receive(:create_status) # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(GithubStatusReporter).to receive(:call).once # rubocop:disable RSpec/AnyInstance
        subject
      end
    end

    context 'when the event is for some other project than the subscribed one' do
      let(:event) { Event::BuildSuccess.create(project: 'some:other:project', package: package.name, repository: repository.name, reason: 'foo') }

      before do
        event
        event_subscription
      end

      it_behaves_like 'not reporting to the SCM'
    end

    context 'when the event is for some other package than the subscribed one' do
      let(:event) { Event::BuildSuccess.create(project: project.name, package: 'some_other_package', repository: repository.name, reason: 'foo') }

      before do
        event
        event_subscription
      end

      it_behaves_like 'not reporting to the SCM'
    end
  end

  describe 'retrying to report to Gitea' do
    subject { described_class.perform_now(event_id: event.id) }

    let(:workflow_run) do
      create(:workflow_run, scm_vendor: 'gitea', hook_event: 'pull_request', hook_action: 'opened', token: token,
                            request_payload: file_fixture('request_payload_gitea_pull_request_opened.json').read)
    end
    let(:event_subscription) do
      EventSubscription.create(token: token,
                               user: user,
                               package: package,
                               receiver_role: 'reader',
                               payload: { scm: 'gitea' },
                               eventtype: 'Event::BuildSuccess',
                               channel: :scm,
                               workflow_run_id: workflow_run.id)
    end
    let(:gitea_client) { instance_spy(GiteaAPI::V1::Client) }

    before do
      ActiveJob::Base.queue_adapter = :test
      freeze_time
      event
      event_subscription
      allow(GiteaAPI::V1::Client).to receive(:new).and_return(gitea_client)
      allow(gitea_client).to receive(:create_commit_status).and_raise(exception)
    end

    after do
      ActiveJob::Base.queue_adapter = :inline
    end

    context 'when Gitea has a transient problem' do
      let(:exception) { GiteaAPI::V1::Client::InternalServerError }

      it 'enqueues the job again right away' do
        expect { subject }.to have_enqueued_job(described_class).at(Time.current)
      end
    end

    context 'when Gitea rate limits us' do
      let(:exception) { GiteaAPI::V1::Client::TooManyRequestsError }

      it 'enqueues the job again after a longer wait' do
        expect { subject }.to have_enqueued_job(described_class).at(1.minute.from_now)
      end
    end

    context 'when the problem is not transient' do
      let(:exception) { GiteaAPI::V1::Client::NotFoundError }

      it 'does not enqueue the job again' do
        expect { subject }.not_to have_enqueued_job(described_class)
      end

      it 'reports the failure to the workflow run' do
        subject
        expect(workflow_run.reload.response_body).to eq('Failed to report back to Gitea: Content not found.')
      end
    end
  end
end
