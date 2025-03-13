RSpec.describe Workflow::Step::BranchPackageStep, :vcr do
  subject do
    described_class.new(step_instructions: step_instructions,
                        token: token,
                        workflow_run: workflow_run)
  end

  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:target_project_name) { "home:#{user.login}" }
  let(:long_commit_sha) { '123456789' }
  let(:request_payload) do
    {
      number: 1,
      pull_request: {
        html_url: 'http://github.com/something',
        base: {
          repo: {
            full_name: 'openSUSE/open-build-service'
          }
        },
        head: {
          sha: long_commit_sha
        }
      },
      repository: {
        name: 'hello_world',
        html_url: 'https://github.com',
        owner: {
          login: 'iggy'
        }
      }
    }.to_json
  end

  let(:step_instructions) do
    {
      source_project: project.name,
      source_package: package.name,
      target_project: target_project_name
    }
  end
  let(:hook_action) { nil }

  let(:workflow_run) do
    create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: hook_action, request_payload: request_payload)
  end

  before do
    login(user)
  end

  describe '#call' do
    let(:project) { create(:project, name: 'foo_project', maintainer: user, url: 'https://my-foo-project.com/example') }
    let(:package) { create(:package_with_file, name: 'bar_package', project: project) }
    let(:final_package_name) { package.name }

    before do
      project
      package
    end

    context 'for a new_commit SCM webhook event' do
      context 'it creates the _branch_request file' do
        let(:hook_action) { 'opened' }

        it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
        it { expect(subject.call.source_file('_branch_request')).to include('123') }

        it 'updates the url' do
          expect(subject.call.project.url).to eq('http://github.com/something')
        end
      end

      context 'it sets the scmsync url' do
        let(:hook_action) { 'opened' }
        let(:scmsync_url) { 'https://github.com/krauselukas/test_scmsync.git' }

        before do
          package.update(scmsync: scmsync_url)
        end

        it { expect(subject.call.scmsync).to eq("#{scmsync_url}##{long_commit_sha}") }
      end

      context 'without branch permissions' do
        let(:hook_action) { 'opened' }
        let(:branch_package_mock) { instance_double(BranchPackage) }

        before do
          allow(BranchPackage).to receive(:new).and_return(branch_package_mock)
          allow(branch_package_mock).to receive(:branch).and_raise(CreateProjectNoPermission)
        end

        it { expect { subject.call }.to raise_error(BranchPackage::Errors::CanNotBranchPackageNoPermission) }
      end

      context 'when the branch target package already exists' do
        let(:hook_action) { 'synchronize' }
        let(:long_commit_sha) { 'abcdefghijk' }

        # Emulate the branched project/package and the subcription created in a previous new PR/MR event
        let!(:branched_project) { create(:project, name: "home:#{user.login}:openSUSE:open-build-service:PR-1", maintainer: user) }
        let!(:branched_package) { create(:package_with_file, name: package.name, project: branched_project) }

        ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
          let!("event_subscription_#{build_event.parameterize}") do
            EventSubscription.create(eventtype: build_event,
                                     receiver_role: 'reader',
                                     user: user,
                                     channel: :scm,
                                     enabled: true,
                                     token: token,
                                     package: branched_package,
                                     payload: workflow_run.payload)
          end
        end

        it { expect { subject.call }.not_to(change(Package, :count)) }
        it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count)) }
        it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count)) }

        context 'it updates the _branch_request file' do
          it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
          it { expect(subject.call.source_file('_branch_request')).to include('abcdefghijk') }
        end

        context 'it updates the scmsync url' do
          let(:scmsync_url) { 'https://github.com/krauselukas/test_scmsync.git' }
          let(:long_commit_sha) { 'abcdefghijk' }

          before do
            package.update(scmsync: scmsync_url)
          end

          it { expect(subject.call.scmsync).to eq("#{scmsync_url}##{long_commit_sha}") }
        end
      end

      context 'when the branch target package does not exist' do
        let(:hook_action) { 'synchronize' }

        it { expect { subject.call }.to(change(Package, :count).by(1)) }
        it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
        it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
      end
    end

    context 'for a closed_merged SCM webhook event' do
      let!(:other_project) { create(:project, name: 'hans:openSUSE:open-build-service:PR-1') }
      let(:hook_action) { 'closed' }
      let(:step_instructions) do
        {
          source_project: package.project.name,
          source_package: package.name,
          target_project: other_project.name.split(':').first
        }
      end

      context 'without target_project permission' do
        it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError, 'not allowed to destroy? this Project') }
      end
    end

    context 'for a reopened event SCM webhook event' do
      let(:hook_action) { 'reopened' }
      let(:step_instructions) do
        {
          source_project: package.project.name,
          source_package: package.name,
          target_project: 'hans'
        }
      end

      context 'without target_project permission' do
        it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError, 'not allowed to create? this Project') }
      end
    end
  end

  describe '.parse_scmsync_for_target_package' do
    let(:project) { create(:project, name: 'foo_scm_synced_project', maintainer: user) }
    let(:package) { create(:package_with_file, name: 'bar_scm_synced_package', project: project) }
    let(:hook_action) { 'opened' }
    let(:scmsync_url) { 'https://github.com/krauselukas/test_scmsync.git' }

    before do
      create(:repository, name: 'Unicorn_123', project: package.project, architectures: %w[x86_64 i586 ppc aarch64])
      create(:repository, name: 'openSUSE_Tumbleweed', project: package.project, architectures: ['x86_64'])
    end

    context 'for scmsync on project level' do
      before do
        project.update(scmsync: scmsync_url)
      end

      it { expect(subject.call.scmsync).to eq("#{scmsync_url}?subdir=#{package.name}##{long_commit_sha}") }
    end

    context 'for scmsync on package level' do
      before do
        package.update(scmsync: scmsync_url)
      end

      it { expect(subject.call.scmsync).to eq("#{scmsync_url}##{long_commit_sha}") }

      context 'with a subdir query' do
        subdir = '?subdir=hello_world01'
        before do
          package.update(scmsync: scmsync_url + subdir)
        end

        it { expect(subject.call.scmsync).to eq("#{scmsync_url}#{subdir}##{long_commit_sha}") }
      end

      context 'with a branch fragment' do
        fragment = '#krauselukas-patch-2'
        before do
          package.update(scmsync: scmsync_url + fragment)
        end

        it { expect(subject.call.scmsync).to eq("#{scmsync_url}##{long_commit_sha}") }
      end

      context 'with a subdir query and a branch fragment' do
        subdir = '?subdir=hello_world01'
        fragment = '#krauselukas-patch-2'
        before do
          package.update(scmsync: scmsync_url + subdir + fragment)
        end

        it { expect(subject.call.scmsync).to eq("#{scmsync_url}#{subdir}##{long_commit_sha}") }
      end
    end
  end

  describe '#skip_repositories?' do
    let(:project) { create(:project, name: 'foo_project', maintainer: user, url: 'https://my-foo-project.com/example') }
    let(:package) { create(:package_with_file, name: 'bar_package', project: project) }
    let(:hook_action) { 'opened' }

    context 'when add_repositories is enabled' do
      let(:step_instructions) { { source_project: package.project.name, source_package: package.name, target_project: target_project_name, add_repositories: 'enabled' } }

      it { expect(subject.send(:skip_repositories?)).not_to be_truthy }
    end

    context 'when add_repositories is disabled' do
      let(:step_instructions) { { source_project: package.project.name, source_package: package.name, target_project: target_project_name, add_repositories: 'disabled' } }

      it { expect(subject.send(:skip_repositories?)).to be_truthy }

      it 'sets the url of the target project with the event url from the SCM payload' do
        expect(subject.call.project.url).to eq('http://github.com/something')
      end
    end

    context 'when add_repositories is blank' do
      it { expect(subject.send(:skip_repositories?)).not_to be_truthy }
    end
  end

  describe '#check_source_access' do
    let(:project) { create(:project, name: 'foo_project', maintainer: user) }
    let(:hook_action) { 'opened' }
    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: 'this_package_does_not_exist',
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to raise_error(BranchPackage::Errors::CanNotBranchPackageNotFound) }
  end
end
