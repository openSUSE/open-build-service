require 'rails_helper'

RSpec.describe Workflow::Step::LinkPackageStep, vcr: true do
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

    it { expect { subject.call }.to raise_error(Package::Errors::UnknownObjectError) }
  end

  RSpec.shared_context 'project and package does not exist' do
    let(:step_instructions) do
      {
        source_project: 'invalid project',
        source_package: 'invalid package',
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to raise_error(Project::Errors::UnknownObjectError) }
  end

  RSpec.shared_context 'target package already exists' do
    # Emulates that the target project and package already existed
    let!(:linked_project) { create(:project, name: "home:#{user.login}:openSUSE:open-build-service:PR-1", maintainer: user) }
    let!(:linked_package) { create(:package_with_file, name: package.name, project: linked_project) }

    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to raise_error(PackageAlreadyExists) }
  end

  RSpec.shared_context 'failed without link permissions' do
    let(:step_instructions) do
      {
        source_project: project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Package).to receive(:disabled_for?).with('sourceaccess', nil, nil).and_return(true)
      # rubocop:enable RSpec/AnyInstance
    end

    it { expect { subject.call }.to raise_error(Package::Errors::ReadSourceAccessError) }
  end

  RSpec.shared_context 'successful new PR or MR event' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to(change(Project, :count).by(1)) }
    it { expect { subject.call }.to(change(Package, :count).by(2)) }
    it { expect(subject.call.project.name).to eq("home:#{user.login}:openSUSE:open-build-service:PR-1") }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count).by(1)) }
    it { expect { subject.call }.to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count).by(1)) }
    it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
    it { expect(subject.call.source_file('_branch_request')).to include('123') }
    it { expect { subject.call.source_file('_link') }.not_to raise_error }
    it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }
    it { expect(subject.call.project.packages.map(&:name)).to include('_project') }
    it { expect { subject.call.project.packages.find_by(name: '_project').source_file('_service') }.not_to raise_error }
  end

  RSpec.shared_context 'successful update event when the linked_package already exists' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

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

    before do
      package.save_file({ file: existing_branch_request_file, filename: '_branch_request' })
    end

    it { expect { subject.call }.not_to(change(Package, :count)) }
    it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
    it { expect { subject.call.source_file('_link') }.not_to raise_error }
    it { expect(subject.call.source_file('_link')).to eq('<link project="foo_project" package="bar_package"/>') }

    it 'updates _branch_request file including new commit sha' do
      expect(subject.call.source_file('_branch_request')).to include('456')
    end

    it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildFail'), :count)) }
    it { expect { subject.call }.not_to(change(EventSubscription.where(eventtype: 'Event::BuildSuccess'), :count)) }
    it { expect { subject.call }.to(change { EventSubscription.where(eventtype: 'Event::BuildSuccess').last.payload }.from(creation_payload).to(update_payload)) }
  end

  RSpec.shared_context 'non-existent linked package' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
        source_package: package.name,
        target_project: target_project_name
      }
    end

    it { expect { subject.call }.to(change(Package, :count).by(2)) }
    it { expect { subject.call }.to(change(EventSubscription, :count).from(0).to(2)) }
  end

  RSpec.shared_context 'insufficient permission on target project' do
    let(:step_instructions) do
      {
        source_project: package.project.name,
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
        source_project: package.project.name,
        source_package: package.name,
        target_project: 'target_project_not_existing'
      }
    end

    it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
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
        it_behaves_like 'project and package does not exist'
        it_behaves_like 'target package already exists'
        it_behaves_like 'failed without link permissions'
        it_behaves_like 'insufficient permission on target project'
        it_behaves_like 'insufficient permission to create new target project'
      end

      context 'for an updated PR event' do
        context 'when the linked package already existed' do
          it_behaves_like 'successful update event when the linked_package already exists' do
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

        context 'when the linked package did not exist' do
          it_behaves_like 'non-existent linked package' do
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
        it_behaves_like 'project and package does not exist'
        it_behaves_like 'target package already exists'
        it_behaves_like 'failed without link permissions'
        it_behaves_like 'insufficient permission on target project'
        it_behaves_like 'insufficient permission to create new target project'
      end

      context 'for an updated MR event' do
        context 'when the linked package already existed' do
          it_behaves_like 'successful update event when the linked_package already exists' do
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

        context 'when the linked package did not exist' do
          it_behaves_like 'non-existent linked package' do
            let(:action) { 'update' }
          end
        end
      end
    end
  end
end
