require 'rails_helper'

RSpec.describe Workflow::Step::BranchPackageStep, vcr: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:target_project_name) { "home:#{user.login}" }
  let(:long_commit_sha) { '123456789' }
  let(:short_commit_sha) { '1234567' }

  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_webhook: scm_webhook,
                        token: token)
  end

  RSpec.shared_context 'source_project not provided' do
    let(:step_instructions) { { source_package: package.name, target_project: target_project_name } }

    it { expect { subject.call }.not_to(change(Package, :count)) }
  end

  RSpec.shared_context 'source_package not provided' do
    let(:step_instructions) { { source_project: package.project.name, target_project: target_project_name } }

    it { expect { subject.call }.not_to(change(Package, :count)) }
  end

  RSpec.shared_context 'failed when source_package does not exist' do
    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: 'this_package_does_not_exist',
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to raise_error(BranchPackage::Errors::CanNotBranchPackageNotFound) }
  end

  RSpec.shared_context 'failed without branch permissions' do
    let(:branch_package_mock) { instance_double(BranchPackage) }
    before do
      allow(BranchPackage).to receive(:new).and_return(branch_package_mock)
      allow(branch_package_mock).to receive(:branch).and_raise(CreateProjectNoPermission)
    end

    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to raise_error(BranchPackage::Errors::CanNotBranchPackageNoPermission) }
  end

  RSpec.shared_context 'successful new PR or MR event' do
    before do
      create(:repository, name: 'Unicorn_123', project: package.project, architectures: ['x86_64', 'i586', 'ppc', 'aarch64'])
      create(:repository, name: 'openSUSE_Tumbleweed', project: package.project, architectures: ['x86_64'])
    end

    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to(change(Package, :count).by(1)) }
    it { expect(subject.call.project.name).to eq(target_project_final_name) }
    it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
    it { expect(subject.call.source_file('_branch_request')).to include('123') }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
  end

  RSpec.shared_context 'successful update event when the branch_package already exists' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

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
                                 payload: creation_payload)
      end
    end

    before do
      package.save_file({ file: existing_branch_request_file, filename: '_branch_request' })
    end

    it { expect { subject.call }.not_to(change(Package, :count)) }
    it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }

    it 'updates _branch_request file including new commit sha' do
      expect(subject.call.source_file('_branch_request')).to include('456')
    end

    it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count)) }
    it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count)) }
    it { expect { subject.call }.to(change { EventSubscription.where(eventtype: 'Event::BuildSuccess').last.payload }.from(creation_payload).to(update_payload)) }
  end

  RSpec.shared_context 'non-existent branched package' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to(change(Package, :count).by(1)) }
    it { expect { subject.call }.to(change(EventSubscription, :count).from(0).to(2)) }
  end

  RSpec.shared_context 'fails with insufficient write permission on target project' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: 'project_without_maintainer_rights'
      }
    end
    let!(:project_without_permission) { create(:project, name: 'project_without_maintainer_rights') }

    it { expect { subject.call }.to raise_error(BranchPackage::Errors::CanNotBranchPackageNoPermission) }
  end

  describe '#call' do
    let(:project) { create(:project, name: 'foo_project', maintainer: user) }
    let(:package) { create(:package_with_file, name: 'bar_package', project: project) }
    let(:target_project_final_name) { "home:#{user.login}:openSUSE:open-build-service:PR-1" }
    let(:final_package_name) { package.name }

    before do
      project
      package
      login(user)
    end

    context 'when the SCM is GitHub' do
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'pull_request',
                         action: action,
                         pr_number: 1,
                         source_repository_full_name: 'reponame',
                         commit_sha: long_commit_sha,
                         target_repository_full_name: 'openSUSE/open-build-service'
                       })
      end

      context "but we don't provide source_project" do
        it_behaves_like 'source_project not provided' do
          let(:action) { 'synchronize' }
        end
      end

      context "but we don't provide a source_package" do
        it_behaves_like 'source_package not provided' do
          let(:action) { 'opened' }
        end
      end

      context 'for a new PR event' do
        let(:action) { 'opened' }
        let(:octokit_client) { instance_double(Octokit::Client) }

        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_return(true)
        end

        it_behaves_like 'successful new PR or MR event'
        it_behaves_like 'failed when source_package does not exist'
        it_behaves_like 'failed without branch permissions'
        it_behaves_like 'fails with insufficient write permission on target project'
      end

      context 'for a multibuild package' do
        let(:action) { 'opened' }
        let(:package) { create(:multibuild_package, name: 'multibuild_package', project: project) }
        let(:octokit_client) { instance_double(Octokit::Client) }
        let(:step_instructions) do
          {
            source_project: package.project.name,
            source_package: package.name,
            target_project: target_project_name
          }
        end

        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_return(true)

          create(:repository, name: 'Unicorn_123', project: package.project, architectures: ['x86_64', 'i586', 'ppc', 'aarch64'])
          create(:repository, name: 'openSUSE_Tumbleweed', project: package.project, architectures: ['x86_64'])
        end

        it { expect { subject.call }.to(change(Package, :count).by(1)) }
        it { expect(subject.call.project.name).to eq(target_project_final_name) }
        it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
        it { expect(subject.call.source_file('_branch_request')).to include('123') }
        it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
        it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
      end

      context 'for an updated PR event' do
        context 'when the branched package already existed' do
          it_behaves_like 'successful update event when the branch_package already exists' do
            let(:action) { 'synchronize' }
            let(:creation_payload) do
              { 'action' => 'opened', 'commit_sha' => long_commit_sha, 'event' => 'pull_request', 'pr_number' => 1, 'scm' => 'github', 'source_repository_full_name' => 'reponame',
                'target_repository_full_name' => 'openSUSE/open-build-service' }
            end
            let(:update_payload) do
              { 'action' => 'synchronize', 'commit_sha' => long_commit_sha, 'event' => 'pull_request', 'pr_number' => 1,
                'scm' => 'github', 'source_repository_full_name' => 'reponame',
                'target_repository_full_name' => 'openSUSE/open-build-service' }
            end
            let(:existing_branch_request_file) do
              {
                action: 'synchronize',
                pull_request: {
                  head: {
                    repo: { full_name: 'source_repository_full_name' },
                    sha: '123'
                  }
                }
              }.to_json
            end
          end
        end

        context 'when the branched package did not exist' do
          it_behaves_like 'non-existent branched package' do
            let(:action) { 'synchronize' }
          end
        end
      end

      context 'with a push event for a commit' do
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'push',
                           target_branch: 'main',
                           source_repository_full_name: 'reponame',
                           commit_sha: long_commit_sha,
                           target_repository_full_name: 'openSUSE/open-build-service',
                           ref: 'refs/heads/branch_123'
                         })
        end

        let(:octokit_client) { instance_double(Octokit::Client) }
        let(:target_project_final_name) { "home:#{user.login}" }
        let(:final_package_name) { "#{package.name}-#{short_commit_sha}" }

        before do
          # branching a package to an existing project doesn't take over the set repositories
          create(:repository, name: 'Unicorn_123', project: user.home_project, architectures: ['x86_64', 'i586', 'ppc', 'aarch64'])
          create(:repository, name: 'openSUSE_Tumbleweed', project: user.home_project, architectures: ['x86_64'])

          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_return(true)
        end

        it_behaves_like 'successful new PR or MR event'
        it_behaves_like 'failed when source_package does not exist'
        it_behaves_like 'failed without branch permissions'
        it_behaves_like 'fails with insufficient write permission on target project'
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
        let(:step_instructions) do
          {
            source_project: package.project.name,
            source_package: package.name,
            target_project: target_project_name
          }
        end

        before do
          # branching a package to an existing project doesn't take over the set repositories
          create(:repository, name: 'Unicorn_123', project: user.home_project, architectures: ['x86_64', 'i586', 'ppc', 'aarch64'])
          create(:repository, name: 'openSUSE_Tumbleweed', project: user.home_project, architectures: ['x86_64'])

          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_return(true)
        end

        it { expect { subject.call }.to(change(Package, :count).by(1)) }
        it { expect(subject.call.project.name).to eq(target_project_final_name) }
        it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
        it { expect(subject.call.source_file('_branch_request')).to include('123456789012345') }
        it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count)) }
        it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count)) }

        it 'does not report back to the SCM' do
          allow(SCMStatusReporter).to receive(:new)
          subject.call
          expect(SCMStatusReporter).not_to have_received(:new)
        end

        it_behaves_like 'failed when source_package does not exist'
        it_behaves_like 'failed without branch permissions'
        it_behaves_like 'fails with insufficient write permission on target project'
      end

      context 'when scmsync is active' do
        let(:project) { create(:project, name: 'foo_scm_synced_project', maintainer: user) }
        let(:package) { create(:package_with_file, name: 'bar_scm_synced_package', project: project) }
        let(:action) { 'opened' }
        let(:octokit_client) { instance_double(Octokit::Client) }
        let(:step_instructions) do
          {
            source_project: package.project.name,
            source_package: package.name,
            target_project: target_project_name
          }
        end
        let(:scmsync_url) { 'https://github.com/krauselukas/test_scmsync.git' }

        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:create_status).and_return(true)

          create(:repository, name: 'Unicorn_123', project: package.project, architectures: ['x86_64', 'i586', 'ppc', 'aarch64'])
          create(:repository, name: 'openSUSE_Tumbleweed', project: package.project, architectures: ['x86_64'])
        end

        context 'on project level' do
          before do
            project.update(scmsync: scmsync_url)
          end

          it { expect(subject.call.scmsync).to eq(scmsync_url + '?subdir=' + package.name + '#' + long_commit_sha) }
          it { expect { subject.call }.to(change(Package, :count).by(1)) }
          it { expect { subject.call.source_file('_branch_request') }.to raise_error(Backend::NotFoundError) }
          it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
          it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
        end

        context 'on package level' do
          before do
            package.update(scmsync: scmsync_url)
          end

          it { expect(subject.call.scmsync).to eq(scmsync_url + '#' + long_commit_sha) }
          it { expect { subject.call }.to(change(Package, :count).by(1)) }
          it { expect { subject.call.source_file('_branch_request') }.to raise_error(Backend::NotFoundError) }
          it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
          it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
        end

        context 'on a package level with a subdir query' do
          subdir = '?subdir=my_awesome_pkg'
          before do
            package.update(scmsync: scmsync_url + subdir)
          end

          it { expect(subject.call.scmsync).to eq(scmsync_url + subdir + '#' + long_commit_sha) }
          it { expect { subject.call.source_file('_branch_request') }.to raise_error(Backend::NotFoundError) }
        end

        context 'on a package level with a branch fragment' do
          fragment = '#my-test-branch'
          before do
            package.update(scmsync: scmsync_url + fragment)
          end

          it { expect(subject.call.scmsync).to eq(scmsync_url + '#' + long_commit_sha) }
          it { expect { subject.call.source_file('_branch_request') }.to raise_error(Backend::NotFoundError) }
        end

        context 'on a package level with a subdir query and a branch fragment' do
          subdir = '?subdir=my_test_pkg'
          fragment = '#my-branch'
          before do
            package.update(scmsync: scmsync_url + subdir + fragment)
          end

          it { expect(subject.call.scmsync).to eq(scmsync_url + subdir + '#' + long_commit_sha) }
          it { expect { subject.call.source_file('_branch_request') }.to raise_error(Backend::NotFoundError) }
        end
      end
    end

    context 'when the SCM is GitLab' do
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'gitlab',
                         event: 'Merge Request Hook',
                         action: action,
                         pr_number: 1,
                         source_repository_full_name: 'reponame',
                         commit_sha: long_commit_sha,
                         path_with_namespace: 'openSUSE/open-build-service'
                       })
      end

      context "but we don't provide source_project" do
        it_behaves_like 'source_project not provided' do
          let(:action) { 'open' }
        end
      end

      context "but we don't provide a source_package" do
        it_behaves_like 'source_package not provided' do
          let(:action) { 'update' }
        end
      end

      context 'for a new MR event' do
        let(:action) { 'open' }
        let(:gitlab_client) { instance_double(Gitlab::Client) }

        before do
          allow(Gitlab).to receive(:client).and_return(gitlab_client)
          allow(gitlab_client).to receive(:update_commit_status).and_return(true)
        end

        it_behaves_like 'successful new PR or MR event'
        it_behaves_like 'failed when source_package does not exist'
        it_behaves_like 'failed without branch permissions'
        it_behaves_like 'fails with insufficient write permission on target project'
      end

      context 'for an updated MR event' do
        context 'when the branched package already existed' do
          it_behaves_like 'successful update event when the branch_package already exists' do
            let(:action) { 'update' }
            let(:creation_payload) do
              { 'action' => 'open', 'commit_sha' => long_commit_sha, 'event' => 'Merge Request Hook',
                'pr_number' => 1, 'scm' => 'gitlab', 'source_repository_full_name' => 'reponame',
                'path_with_namespace' => 'openSUSE/open-build-service' }
            end
            let(:update_payload) do
              { 'action' => 'update', 'commit_sha' => long_commit_sha, 'event' => 'Merge Request Hook',
                'pr_number' => 1, 'scm' => 'gitlab', 'source_repository_full_name' => 'reponame',
                'path_with_namespace' => 'openSUSE/open-build-service' }
            end
            let(:existing_branch_request_file) do
              { object_kind: 'update',
                project: { http_url: 'http_url' },
                object_attributes: { source: { default_branch: '123' } } }.to_json
            end
          end
        end

        context 'when the branched package did not exist' do
          it_behaves_like 'non-existent branched package' do
            let(:action) { 'update' }
          end
        end
      end

      context 'with a push event for a commit' do
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'gitlab',
                           event: 'Push Hook',
                           target_branch: 'main',
                           source_repository_full_name: 'reponame',
                           commit_sha: long_commit_sha,
                           path_with_namespace: 'openSUSE/open-build-service'
                         })
        end

        let(:gitlab_client) { instance_double(Gitlab::Client) }
        let(:target_project_final_name) { "home:#{user.login}" }
        let(:final_package_name) { "#{package.name}-#{short_commit_sha}" }

        before do
          # branching a package to an existing project doesn't take over the set repositories
          create(:repository, name: 'Unicorn_123', project: user.home_project, architectures: ['x86_64', 'i586', 'ppc', 'aarch64'])
          create(:repository, name: 'openSUSE_Tumbleweed', project: user.home_project, architectures: ['x86_64'])

          allow(Gitlab).to receive(:client).and_return(gitlab_client)
          allow(gitlab_client).to receive(:update_commit_status).and_return(true)
        end

        it_behaves_like 'successful new PR or MR event'
        it_behaves_like 'failed when source_package does not exist'
        it_behaves_like 'failed without branch permissions'
        it_behaves_like 'fails with insufficient write permission on target project'
      end
    end
  end

  describe '#validate_source_project_and_package_name' do
    let(:project) { create(:project, name: 'foo_project', maintainer: user) }
    let(:package) { create(:package_with_file, name: 'bar_package', project: project) }
    let(:scm_webhook) do
      SCMWebhook.new(payload: {
                       scm: 'github',
                       event: 'pull_request',
                       action: 'opened',
                       pr_number: 1,
                       source_repository_full_name: 'reponame',
                       commit_sha: long_commit_sha,
                       target_repository_full_name: 'openSUSE/open-build-service'
                     })
    end

    context 'when the source project is invalid' do
      let(:step_instructions) { { source_project: 'Invalid/format', source_package: package.name, target_project: target_project_name } }

      it 'gives an error for invalid name' do
        subject.valid?

        expect { subject.call }.not_to change(Package, :count)
        expect(subject.errors.full_messages.to_sentence).to eq("invalid source project 'Invalid/format'")
      end
    end

    context 'when the source package is invalid' do
      let(:step_instructions) { { source_project: package.project.name, source_package: 'Invalid/format', target_project: target_project_name } }

      it 'gives an error for invalid name' do
        subject.valid?

        expect { subject.call }.not_to change(Package, :count)
        expect(subject.errors.full_messages.to_sentence).to eq("invalid source package 'Invalid/format'")
      end
    end
  end
end
