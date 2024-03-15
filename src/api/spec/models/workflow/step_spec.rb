RSpec.describe Workflow::Step do
  describe '#target_package_name' do
    subject { described_class.new(step_instructions: step_instructions, scm_webhook: scm_webhook).send(:target_package_name) }

    context 'for a pull request_event when target_package is in the step instructions' do
      let(:step_instructions) { { target_package: 'hello_world' } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'pull_request' }) }

      it 'returns the value of target_package' do
        expect(subject).to eq('hello_world')
      end
    end

    context 'for a pull request_event when target_package is not in the step instructions' do
      let(:step_instructions) { { source_package: 'package123' } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'pull_request' }) }

      it 'returns the name of the source package' do
        expect(subject).to eq('package123')
      end
    end

    context 'with a push event for a commit when target_package is in the step instructions' do
      let(:step_instructions) { { target_package: 'hello_world' } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/heads/main', commit_sha: '456' }) }

      it 'returns the value of target_package with the commit SHA as a suffix' do
        expect(subject).to eq('hello_world-456')
      end
    end

    context 'with a push event for a commit when target_package is not in the step instructions' do
      let(:step_instructions) { { source_package: 'package123' } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/heads/main', commit_sha: '456' }) }

      it 'returns the name of the source package with the commit SHA as a suffix' do
        expect(subject).to eq('package123-456')
      end
    end

    context 'with a push event for a tag when target_package is in the step instructions' do
      let(:step_instructions) { { target_package: 'hello_world' } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/tags/release_abc', tag_name: 'release_abc' }) }

      it 'returns the value of target_package with the tag name as a suffix' do
        expect(subject).to eq('hello_world-release_abc')
      end
    end

    context 'with a push event for a tag when target_package is not in the step instructions' do
      let(:step_instructions) { { source_package: 'package123' } }
      let(:scm_webhook) { SCMWebhook.new(payload: { scm: 'github', event: 'push', ref: 'refs/tags/release_abc', tag_name: 'release_abc' }) }

      it 'returns the name of the source package with the tag name as a suffix' do
        expect(subject).to eq('package123-release_abc')
      end
    end
  end

  describe '#target_project_name' do
    subject do
      step.new(step_instructions: step_instructions, scm_webhook: scm_webhook).target_project_name
    end

    let(:step) do
      Class.new(described_class) do
        def self.name
          'MyStepClass'
        end

        def target_project_base_name
          'OBS:Server:Unstable'
        end
      end
    end

    let(:step_instructions) do
      {
        project: 'OBS:Server:Unstable',
        repositories:
          [
            {
              name: 'openSUSE_Tumbleweed',
              target_project: 'openSUSE:Factory',
              target_repository: 'snapshot',
              architectures: %w[
                x86_64
                ppc
              ]
            }
          ]
      }
    end
    let(:scm_webhook) { SCMWebhook.new(payload: payload) }

    context 'for an unsupported event' do
      let(:payload) do
        {
          scm: 'github',
          event: 'unsupported'
        }
      end

      it { is_expected.to be_nil }
    end

    context 'for a pull request webhook event' do
      context 'from GitHub' do
        let(:payload) do
          {
            scm: 'github',
            event: 'pull_request',
            pr_number: 1,
            target_repository_full_name: 'openSUSE/repo123'
          }
        end

        it { is_expected.to eq('OBS:Server:Unstable:openSUSE:repo123:PR-1') }
      end

      context 'from GitLab' do
        let(:payload) do
          {
            scm: 'gitlab',
            event: 'Merge Request Hook',
            pr_number: 1,
            target_repository_full_name: 'openSUSE/repo123'
          }
        end

        it { is_expected.to eq('OBS:Server:Unstable:openSUSE:repo123:PR-1') }
      end
    end

    context 'with a push webhook event for a commit' do
      context 'from GitHub' do
        let(:payload) { { scm: 'github', event: 'push', ref: 'refs/heads/branch_123' } }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end

      context 'from GitLab' do
        let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end
    end

    context 'with a push webhook event for a tag' do
      context 'from GitHub' do
        let(:payload) { { scm: 'github', event: 'push', ref: 'refs/tags/release_abc' } }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end

      context 'from GitLab' do
        let(:payload) { { scm: 'gitlab', event: 'Tag Push Hook' } }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end
    end
  end

  describe '#validate_project_names_in_step_instructions' do
    before do
      subject.valid?
    end

    context 'when the project is invalid' do
      subject { Workflow::Step::RebuildPackage.new(step_instructions: { project: 'Invalid/format', package: 'franz' }) }

      it 'gives an error for invalid name' do
        expect(subject.errors.full_messages.to_sentence).to eq("invalid project: 'Invalid/format'")
      end
    end

    context 'when the source project is invalid' do
      subject { Workflow::Step::BranchPackageStep.new(step_instructions: { source_project: 'Invalid/format', source_package: 'hans', target_project: 'franz' }) }

      it 'gives an error for invalid name' do
        expect(subject.errors.full_messages.to_sentence).to eq("invalid source_project: 'Invalid/format'")
      end
    end

    context 'when the target project is invalid' do
      subject { Workflow::Step::BranchPackageStep.new(step_instructions: { source_project: 'hans', source_package: 'franz', target_project: 'Invalid/format' }) }

      it 'gives an error for invalid name' do
        expect(subject.errors.full_messages.to_sentence).to eq("invalid target_project: 'Invalid/format'")
      end
    end
  end

  describe '#validate_package_names_in_step_instructions' do
    before do
      subject.valid?
    end

    context 'when the package is invalid' do
      subject { Workflow::Step::RebuildPackage.new(step_instructions: { project: 'hans', package: 'Invalid/format' }) }

      it 'gives an error for invalid name' do
        expect(subject.errors.full_messages.to_sentence).to eq("invalid package: 'Invalid/format'")
      end
    end

    context 'when the source package is invalid' do
      subject { Workflow::Step::BranchPackageStep.new(step_instructions: { source_project: 'hans', source_package: 'Invalid/format', target_project: 'franz' }) }

      it 'gives an error for invalid name' do
        expect(subject.errors.full_messages.to_sentence).to eq("invalid source_package: 'Invalid/format'")
      end
    end

    context 'when the target package is invalid' do
      subject { Workflow::Step::BranchPackageStep.new(step_instructions: { source_project: 'hans', source_package: 'franz', target_project: 'peter', target_package: 'Invalid/format' }) }

      it 'gives an error for invalid name' do
        expect(subject.errors.full_messages.to_sentence).to eq("invalid target_package: 'Invalid/format'")
      end
    end
  end

  describe '#validate_required_keys_in_step_instructions' do
    subject { Workflow::Step::RebuildPackage.new(step_instructions: step_instructions) }

    before do
      subject.valid?
    end

    context 'key not provided' do
      let(:step_instructions) { { package: 'hans' } }

      it 'gives an error for invalid name' do
        expect(subject.errors[:base]).to include("The 'project' key is missing")
      end
    end

    context 'value not provided' do
      let(:step_instructions) { { project: '', package: 'hans' } }

      it 'gives an error for invalid name' do
        expect(subject.errors[:base]).to include("The 'project' key must provide a value")
      end
    end
  end
end
