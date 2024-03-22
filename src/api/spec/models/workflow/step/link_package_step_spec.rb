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

  describe '#call' do
    before do
      login(user)
    end

    context 'for a new PR event' do
      let(:action) { 'opened' }

      it { expect { subject.call }.to(change(Project, :count).by(1)) }
      it { expect { subject.call }.to(change(Package, :count).by(1)) }
      it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
      it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
      it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }

      context 'insufficient permission for target project' do
        let(:step_instructions) do
          {
            source_project: project.name,
            source_package: package.name,
            target_project: 'hans'
          }
        end
        let!(:target_project_no_permission) { create(:project, name: 'hans:openSUSE:open-build-service:PR-1') }

        it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError, 'not allowed to create? this Package') }
      end

      context 'insufficient permission for target package' do
        let(:target_project) { create(:project, name: 'hans:openSUSE:open-build-service:PR-1') }
        let(:target_package) { create(:package, name: 'franz', project: target_project) }
        let(:step_instructions) do
          {
            source_project: project.name,
            source_package: package.name,
            target_project: target_project.name.split(':').first,
            target_package: target_package.name
          }
        end

        it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError, 'not allowed to update? this Package') }
      end

      context 'insufficient permission to create new target project' do
        let(:step_instructions) do
          {
            source_project: project.name,
            source_package: package.name,
            target_project: 'target_project_not_existing'
          }
        end

        it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError, 'not allowed to create? this Project') }
      end
    end
  end
end
