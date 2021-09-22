require 'rails_helper'

RSpec.describe Workflow::Step::BranchPackageStep, vcr: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, user: user) }
  let(:target_project_name) { "home:#{user.login}" }

  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_webhook: scm_webhook,
                        token: token)
  end

  RSpec.shared_context 'source_project not provided' do
    let(:step_instructions) { { source_package: package.name, target_project: target_project_name } }

    it { expect { subject.call }.to(change(Package, :count).by(0)) }
  end

  RSpec.shared_context 'source_package not provided' do
    let(:step_instructions) { { source_project: package.project.name, target_project: target_project_name } }

    it { expect { subject.call }.to(change(Package, :count).by(0)) }
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
    let(:branch_package_mock) { instance_double('BranchPackage') }
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

    let(:workflow_filters) do
      { architectures: { only: ['x86_64', 'i586'] }, repositories: { ignore: ['openSUSE_Tumbleweed'] } }
    end

    let(:target_project_name_with_pr_suffix) { "home:#{user.login}:openSUSE:open-build-service:PR-1" }

    it { expect { subject.call }.to(change(Package, :count).by(1)) }
    it { expect(subject.call.project.name).to eq("home:#{user.login}:openSUSE:open-build-service:PR-1") }
    it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
    it { expect(subject.call.source_file('_branch_request')).to include('123') }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }

    # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/MessageSpies
    # RSpec/MultipleExpectations, RSpec/ExampleLength - We want to test those expectations together since they depend on each other to be true
    # RSpec/MesssageSpies - The method `and_call_original` isn't available on `have_received`, so we need to use `receive`
    it 'only reports for repositories and architectures matching the filters' do
      expect(SCMStatusReporter).to receive(:new).with({ project: target_project_name_with_pr_suffix, package: package.name, repository: 'Unicorn_123', arch: 'i586' },
                                                      scm_webhook.payload, token.scm_token).and_call_original
      expect(SCMStatusReporter).to receive(:new).with({ project: target_project_name_with_pr_suffix, package: package.name, repository: 'Unicorn_123', arch: 'x86_64' },
                                                      scm_webhook.payload, token.scm_token).and_call_original

      expect(SCMStatusReporter).not_to receive(:new).with({ project: target_project_name_with_pr_suffix, package: package.name, repository: 'Unicorn_123', arch: 'ppc' },
                                                          scm_webhook.payload, token.scm_token)
      expect(SCMStatusReporter).not_to receive(:new).with({ project: target_project_name_with_pr_suffix, package: package.name, repository: 'Unicorn_123', arch: 'aarch64' },
                                                          scm_webhook.payload, token.scm_token)
      expect(SCMStatusReporter).not_to receive(:new).with({ project: target_project_name_with_pr_suffix, package: package.name, repository: 'openSUSE_Tumbleweed', arch: 'x86_64' },
                                                          scm_webhook.payload, token.scm_token)

      subject.call({ workflow_filters: workflow_filters })
    end
    # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/MessageSpies
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

    it { expect { subject.call }.to(change(Package, :count).by(0)) }
    it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }

    it 'updates _branch_request file including new commit sha' do
      expect(subject.call.source_file('_branch_request')).to include('456')
    end

    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(0)) }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(0)) }
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

    before do
      project
      package
      login(user)
    end

    context 'when the SCM is GitHub' do
      let(:commit_sha) { '123' }
      let(:scm_webhook) do
        ScmWebhook.new(payload: {
                         scm: 'github',
                         event: 'pull_request',
                         action: action,
                         pr_number: 1,
                         source_repository_full_name: 'reponame',
                         commit_sha: commit_sha,
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

      context 'for an updated PR event' do
        context 'when the branched package already existed' do
          it_behaves_like 'successful update event when the branch_package already exists' do
            let(:action) { 'synchronize' }
            let(:creation_payload) do
              { 'action' => 'opened', 'commit_sha' => '456', 'event' => 'pull_request', 'pr_number' => 1, 'scm' => 'github', 'source_repository_full_name' => 'reponame',
                'target_repository_full_name' => 'openSUSE/open-build-service' }
            end
            let(:update_payload) do
              { 'action' => 'synchronize', 'commit_sha' => '456', 'event' => 'pull_request', 'pr_number' => 1, 'scm' => 'github', 'source_repository_full_name' => 'reponame',
                'target_repository_full_name' => 'openSUSE/open-build-service', 'workflow_filters' => {} }
            end
            let(:commit_sha) { '456' }
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
    end

    context 'when the SCM is GitLab' do
      let(:commit_sha) { '123' }
      let(:scm_webhook) do
        ScmWebhook.new(payload: {
                         scm: 'gitlab',
                         event: 'Merge Request Hook',
                         action: action,
                         pr_number: 1,
                         source_repository_full_name: 'reponame',
                         commit_sha: commit_sha,
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
              { 'action' => 'open', 'commit_sha' => '456', 'event' => 'Merge Request Hook', 'pr_number' => 1, 'scm' => 'gitlab', 'source_repository_full_name' => 'reponame',
                'path_with_namespace' => 'openSUSE/open-build-service' }
            end
            let(:update_payload) do
              { 'action' => 'update', 'commit_sha' => '456', 'event' => 'Merge Request Hook', 'pr_number' => 1, 'scm' => 'gitlab', 'source_repository_full_name' => 'reponame',
                'path_with_namespace' => 'openSUSE/open-build-service', 'workflow_filters' => {} }
            end
            let(:commit_sha) { '456' }
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
    end
  end
end
