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

  shared_examples 'reports to the SCM' do
    it 'does call the scm reporter' do
      allow_any_instance_of(Octokit::Client).to receive(:create_status) # rubocop:disable RSpec/AnyInstance
      expect_any_instance_of(GithubStatusReporter).to receive(:call).once # rubocop:disable RSpec/AnyInstance
      subject
    end
  end

  describe '#perform' do
    subject { described_class.perform_now(event.id) }

    context 'happy path' do
      before do
        event
        event_subscription
      end

      it_behaves_like 'reports to the SCM'
    end

    context 'when using a non-allowed event' do
      let(:event) do
        Event::Commit.create(project: project.name, package: package.name)
      end

      before do
        event
        event_subscription
      end

      it_behaves_like 'not reporting to the SCM'
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

    context 'when the reporting raises an error' do
      let(:event) { Event::BuildSuccess.create(project: project.name, package: package.name, repository: repository.name, reason: 'foo') }

      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_status).and_raise(StandardError, '42') # rubocop:disable RSpec/AnyInstance
        event
        event_subscription
      end

      it 'does not call the scm reporter' do
        expect_any_instance_of(GithubStatusReporter).to receive(:call).once # rubocop:disable RSpec/AnyInstance
        subject
      end
    end
  end
end
