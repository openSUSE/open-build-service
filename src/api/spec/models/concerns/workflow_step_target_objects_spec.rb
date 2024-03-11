RSpec.describe WorkflowStepTargetObjects do
  let(:step_instructions) { { source_project: 'hans', source_package: 'franz', target_project: 'hello' } }

  describe '.target_package_name' do
    subject { Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions, scm_webhook: scm_webhook).send(:target_package_name) }

    context 'for a pull request_event' do
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'pull_request' }) }

      context 'when target_package is in the step instructions' do
        let(:step_instructions) { { target_package: 'package123' } }

        it { is_expected.to eq('package123') }
      end

      context 'when target_package is not in the step instructions' do
        it { is_expected.to eq('franz') }
      end
    end

    context 'with a push event for a commit' do
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/heads/main', commit_sha: '456' }) }

      context 'when target_package is in the step instructions' do
        let(:step_instructions) { { target_package: 'package123' } }

        it { is_expected.to eq('package123-456') }
      end

      context 'when target_package is not in the step instructions' do
        it { is_expected.to eq('franz-456') }
      end
    end

    context 'with a push event for a tag' do
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/tags/release_abc', tag_name: 'release_1' }) }

      context 'when target_package is in the step instructions' do
        let(:step_instructions) { { target_package: 'package123' } }

        it { is_expected.to eq('package123-release_1') }
      end

      context 'when target_package is not in the step instructions' do
        it { is_expected.to eq('franz-release_1') }
      end
    end
  end

  describe '.target_project_name' do
    subject { Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions, scm_webhook: scm_webhook).send(:target_project_name) }

    context 'for an unsupported event' do
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'unsupported', repository_name: 'openSUSE/repo123' }) }

      it { is_expected.to eq('hello') }
    end

    context 'for a pull request webhook event' do
      context 'from GitHub' do
        let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'pull_request', pr_number: 1, repository_name: 'openSUSE/repo123' }) }

        it { is_expected.to eq('hello:openSUSE:repo123:PR-1') }
      end

      context 'from GitLab' do
        let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'gitlab', event: 'Merge Request Hook', pr_number: 1, repository_name: 'openSUSE/repo123' }) }

        it { is_expected.to eq('hello:openSUSE:repo123:PR-1') }
      end
    end

    context 'with a push webhook event for a commit' do
      context 'from GitHub' do
        let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/heads/branch_123' }) }

        it { is_expected.to eq('hello') }
      end

      context 'from GitLab' do
        let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'gitlab', event: 'Push Hook' }) }

        it { is_expected.to eq('hello') }
      end
    end

    context 'with a push webhook event for a tag' do
      context 'from GitHub' do
        let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/tags/release_abc' }) }

        it { is_expected.to eq('hello') }
      end

      context 'from GitLab' do
        let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'gitlab', event: 'Tag Push Hook' }) }

        it { is_expected.to eq('hello') }
      end
    end
  end

  describe '.authorize_target_project' do
    let(:token) { create(:token) }
    let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'pull_request' }) }

    subject { Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions, token: token, scm_webhook: scm_webhook) }

    context 'when existing target_project is not writeable' do
      let(:target_project) { create(:project_with_package) }
      let(:target_package) { target_project.packages.first }
      let(:step_instructions) { { target_project: target_project.name, target_package: target_package.name } }

      it { expect { subject.send(:authorize_target_project) }.to raise_error(Pundit::NotAuthorizedError) }
    end

    context 'when target_project is not createable' do
      let(:step_instructions) { { target_project: 'target_project', target_package: 'target_package', token: token } }

      it { expect { subject.send(:authorize_target_project) }.to raise_error(Pundit::NotAuthorizedError) }
    end
  end
end
