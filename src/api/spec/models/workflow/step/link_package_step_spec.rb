RSpec.describe Workflow::Step::LinkPackageStep, :vcr do
  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_webhook: scm_webhook,
                        token: token)
  end

  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:target_project) { user.home_project }
  let!(:project) { create(:project, name: 'foo_project', maintainer: user) }
  let!(:package) { create(:package_with_file, name: 'bar_package', project: project) }
  let(:step_instructions) do
    {
      source_project: project.name,
      source_package: package.name,
      target_project: target_project.name
    }
  end
  let(:action) { 'opened' }
  let(:commit_sha) { '123' }
  let(:scm_webhook) do
    SCMWebhook.new(payload: {
                     scm: 'github',
                     event: 'pull_request',
                     action: action,
                     pr_number: 1,
                     source_repository_full_name: 'reponame',
                     commit_sha: commit_sha,
                     target_repository_full_name: 'openSUSE/open-build-service'
                   })
  end

  RSpec.shared_context 'insufficient permission on target project' do
    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: package.name,
        target_project: 'target_project_no_permission'
      }
    end

    let!(:target_project_no_permission) { create(:project, name: 'target_project_no_permission') }

    it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
  end

  RSpec.shared_context 'insufficient permission to create new target project' do
    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: package.name,
        target_project: 'target_project_not_existing'
      }
    end

    it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
  end

  describe '#call' do
    before do
      login(user)
    end

    context 'for a new PR event' do
      let(:action) { 'opened' }

      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:create_status).and_return(true)
      end

      it { expect { subject.call }.to(change(Project, :count).by(1)) }
      it { expect { subject.call }.to(change(Package, :count).by(1)) }
      it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
      it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
      it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }

      it_behaves_like 'insufficient permission on target project'
      it_behaves_like 'insufficient permission to create new target project'
    end

    context 'for an updated PR event' do
      context 'when the linked package already existed' do
        let(:action) { 'synchronize' }
        let(:creation_payload) do
          { 'action' => 'opened', 'commit_sha' => '456', 'event' => 'pull_request', 'pr_number' => 1, 'scm' => 'github', 'source_repository_full_name' => 'reponame',
            'target_repository_full_name' => 'openSUSE/open-build-service' }
        end
        let(:update_payload) do
          { 'action' => 'synchronize', 'commit_sha' => '456', 'event' => 'pull_request', 'pr_number' => 1, 'scm' => 'github',
            'source_repository_full_name' => 'reponame', 'target_repository_full_name' => 'openSUSE/open-build-service' }
        end
        let(:commit_sha) { '456' }


        # Emulate the linked project/package and the subcription created in a previous new PR/MR event
        let!(:linked_project) { create(:project, name: "home:#{user.login}:openSUSE:open-build-service:PR-1", maintainer: user) }
        let!(:linked_package) { create(:package_with_file, name: package.name, project: linked_project) }

        ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
          let!("event_subscription_#{build_event.parameterize}") do
            EventSubscription.create(eventtype: build_event,
                                     receiver_role: 'reader',
                                     user: user,
                                     channel: :scm,
                                     enabled: true,
                                     token: token,
                                     package: linked_package,
                                     payload: creation_payload)
          end
        end

        it { expect { subject.call }.not_to(change(Package, :count)) }
        it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }
        it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count)) }
        it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count)) }
        it { expect { subject.call }.to(change { EventSubscription.where(eventtype: 'Event::BuildSuccess').last.payload }.from(creation_payload).to(update_payload)) }
      end

      context 'when the linked package did not exist' do
        let(:action) { 'synchronize' }

        it { expect { subject.call }.to(change(Package, :count).by(1)) }
        it { expect { subject.call }.to(change(EventSubscription, :count).from(0).to(2)) }
      end
    end

    context 'with a push event for a commit' do
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'push',
                         target_branch: 'main',
                         source_repository_full_name: 'reponame',
                         commit_sha: commit_sha,
                         target_repository_full_name: 'openSUSE/open-build-service',
                         ref: 'refs/heads/branch_123'
                       })
      end
      let(:octokit_client) { instance_double(Octokit::Client) }

      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:create_status).and_return(true)
      end

      it { expect { subject.call }.not_to(change(Project, :count)) }
      it { expect { subject.call }.to(change(Package, :count).by(1)) }
      it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
      it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
      it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }

      it_behaves_like 'insufficient permission on target project'
      it_behaves_like 'insufficient permission to create new target project'
    end

    context 'with a push event for a tag' do
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'push',
                         target_branch: '123456789012345',
                         source_repository_full_name: 'openSUSE/open-build-service',
                         tag_name: 'release_abc',
                         commit_sha: '123456789012345',
                         target_repository_full_name: 'openSUSE/open-build-service',
                         ref: 'refs/tags/release_abc'
                       })
      end
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:target_project_final_name) { "home:#{user.login}" }
      let(:final_package_name) { "#{package.name}-release_abc" }

      before do
        # branching a package to an existing project doesn't take over the set repositories
        create(:repository, name: 'Unicorn_123', project: user.home_project, architectures: %w[x86_64 i586 ppc aarch64])
        create(:repository, name: 'openSUSE_Tumbleweed', project: user.home_project, architectures: ['x86_64'])

        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:create_status).and_return(true)
      end

      it 'does not report back to the SCM' do
        allow(SCMStatusReporter).to receive(:new)
        subject.call
        expect(SCMStatusReporter).not_to have_received(:new)
      end

      it { expect { subject.call }.not_to(change(Project, :count)) }
      it { expect { subject.call }.to(change(Package, :count).by(1)) }
      it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count)) }
      it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count)) }
      it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }

      it_behaves_like 'insufficient permission on target project'
      it_behaves_like 'insufficient permission to create new target project'
    end
  end
end
