RSpec.describe Workflow::Step::SubmitRequest, :vcr do
  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_webhook: scm_webhook,
                        token: token,
                        workflow_run: workflow_run)
  end

  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:other_user) { create(:confirmed_user, :with_home, login: 'Foo') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:source_maintainer) { user }
  let!(:project) { create(:project, name: 'foo_project', maintainer: source_maintainer) }
  let!(:package) { create(:package_with_file, name: 'bar_package', project: project) }
  let(:target_project) { create(:project, name: 'baz_project') }
  let(:scm_webhook) do
    SCMWebhook.new(payload: {
                     scm: 'github',
                     event: 'pull_request',
                     action: action,
                     number: 1,
                     source_repository_full_name: 'reponame',
                     commit_sha: '123456789',
                     target_repository_full_name: 'openSUSE/open-build-service'
                   })
  end
  let(:step_instructions) do
    {
      source_project: package.project.name,
      source_package: package.name,
      target_project: target_project.name
    }
  end
  let(:workflow_run) { create(:workflow_run, token: token) }

  describe '#call' do
    before do
      login(user)
      allow(Backend::Api::Sources::Package).to receive(:wait_service).and_return(true)
    end

    context 'for a newly opened PR' do
      let(:action) { 'opened' }

      it 'creates a submit request' do
        expect { subject.call }.to(change(BsRequest.where(state: 'new'), :count).by(1))
      end

      it 'creates an event subcription' do
        expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::RequestStatechange'), :count).by(1))
      end
    end

    context 'for a closed PR' do
      let(:action) { 'closed' }

      context 'when the token user is authorized' do
        let!(:bs_request) do
          create(:bs_request_with_submit_action, source_project: project, source_package: package,
                                                 target_project: target_project,
                                                 target_package: package.name, creator: user)
        end

        it 'revokes previous submit requests' do
          expect do
            subject.call
            bs_request.reload
          end.to(change(bs_request, :state).from(:new).to(:revoked))
          expect { subject.call }.not_to change(BsRequest, :count)
        end
      end
    end

    context 'for an updated PR' do
      let(:action) { 'synchronize' }

      context 'when the token user is authorized' do
        let!(:bs_request) do
          create(:bs_request_with_submit_action, source_project: project, source_package: package,
                                                 target_project: target_project,
                                                 target_package: package.name, creator: user)
        end

        it 'supersedes previously created submit request and opens a new one' do
          expect { subject.call }.to(change(BsRequest.where.not(id: bs_request.id).where(state: 'new'), :count).by(1))
          expect do
            subject.call
            bs_request.reload
          end.to(change(bs_request, :state).from(:new).to(:superseded))
        end
      end

      context 'when the token user is not authorized' do
        let(:source_maintainer) { other_user }
        let!(:bs_request) do
          create(:bs_request_with_submit_action, source_project: project, source_package: package,
                                                 target_project: target_project,
                                                 target_package: package.name, creator: other_user)
        end

        it 'does not supersede the previously created submit request' do
          expect { subject.call }.to raise_error(PostRequestNoPermission)
        end
      end
    end

    context 'for a push event' do
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'push',
                         target_branch: 'main',
                         source_repository_full_name: 'reponame',
                         commit_sha: '123456789',
                         target_repository_full_name: 'openSUSE/open-build-service',
                         ref: 'refs/heads/branch_123',
                         number: 1
                       })
      end

      it 'creates a submit request' do
        expect { subject.call }.to(change(BsRequest.where(state: 'new'), :count).by(1))
      end

      it 'creates an event subcription' do
        expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::RequestStatechange'), :count).by(1))
      end
    end

    context 'for a tag push event' do
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'push',
                         target_branch: 'main',
                         source_repository_full_name: 'reponame',
                         commit_sha: '123456789',
                         target_repository_full_name: 'openSUSE/open-build-service',
                         ref: 'refs/tags/release_abc',
                         number: 1
                       })
      end

      it 'creates a submit request' do
        expect { subject.call }.to(change(BsRequest.where(state: 'new'), :count).by(1))
      end

      it 'creates no event subcription' do
        expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::RequestStatechange'), :count))
      end
    end
  end
end
