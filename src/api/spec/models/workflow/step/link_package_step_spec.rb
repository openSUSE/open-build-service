RSpec.describe Workflow::Step::LinkPackageStep, :vcr do
  subject do
    described_class.new(step_instructions: step_instructions,
                        token: token,
                        workflow_run: workflow_run)
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

  let(:request_payload) do
    '{
      "action": "opened",
      "number": 1,
      "pull_request": {
        "html_url": "http://github.com/something",
        "base": {
          "repo": {
            "full_name": "openSUSE/open-build-service"
          }
        }
      },
      "repository": {
        "name": "hello_world",
        "html_url": "https://github.com",
        "owner": {
          "login": "iggy"
        }
      }
    }'
  end

  let(:workflow_run) do
    create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload)
  end

  describe 'Validations' do
    describe '#validate_target_project_or_package_are_not_scmsynced' do
      context 'when the target project is developed in SCM' do
        before do
          allow(subject).to receive(:target_project).and_return(target_project)
          target_project.update(scmsync: 'https://github.com/foo/bar')
          subject.valid?
        end

        it 'adds a validation error' do
          expect(subject.errors[:base]).to include("project '#{step_instructions[:target_project]}' is developed in SCM. Branch it instead.")
        end
      end

      context 'when the target package is developed in SCM' do
        let(:step_instructions) { super().merge(target_package: 'hello_world_linked') }
        let!(:target_package) { create(:package, project: target_project, name: 'hello_world_linked', scmsync: 'https://github.com/foo/bar') }

        before do
          allow(subject).to receive(:target_package).and_return(target_package)
          subject.valid?
        end

        it 'adds a validation error' do
          expect(subject.errors[:base]).to include("package 'hello_world_linked' is developed in SCM. Branch it instead.")
        end
      end

      context 'when target_package is not specified in step_instructions' do
        let!(:target_package) { create(:package, project: target_project, name: package.name, scmsync: 'https://github.com/foo/bar') }

        before do
          allow(subject).to receive(:target_package).and_return(target_package)
          subject.valid?
        end

        it 'does not add a validation error for the package' do
          expect(subject.errors[:base]).not_to include(/package .* is developed in SCM/)
        end
      end
    end
  end

  describe '#call' do
    before do
      login(user)
    end

    context 'for a new PR event' do
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
