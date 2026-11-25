RSpec.describe Workflow, :vcr do
  subject do
    described_class.new(workflow_instructions: yaml, token: token, workflow_run: workflow_run)
  end

  let(:user) { create(:confirmed_user, :with_home, login: 'cameron') }
  let(:token) { create(:workflow_token, executor: user) }

  describe '#call' do
    let(:yaml) do
      { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package', 'target_project' => 'test-target-project',
                                            'target_package' => 'test-target-package' } }] }
    end

    context 'with an unsupported event filter' do
      let(:yaml) { { filters: { event: 'nonexistent' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitHub "pull_request" event not matching the "push" event filter' do
      let(:yaml) { { filters: { event: 'push' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitHub "push" event not matching the "pull_request" event filter' do
      let(:yaml) { { filters: { event: 'pull_request' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'push', hook_action: 'opened', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitHub "push" event not matching the "tag_push" event filter' do
      let(:yaml) { { filters: { event: 'tag_push' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'push', hook_action: 'opened', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitLab "Merge Request Hook" event not matching the "push" event filter' do
      let(:yaml) { { filters: { event: 'push' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'gitlab', hook_event: 'Merge Request Hook', hook_action: 'update', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitLab "Push Hook" event not matching the "pull_request" event filter' do
      let(:yaml) { { filters: { event: 'pull_request' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'gitlab', hook_event: 'Push Hook', hook_action: 'update', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitLab "Push Hook" event not matching the "tag_push" event filter' do
      let(:yaml) { { filters: { event: 'tag_push' } } }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'gitlab', hook_event: 'Push Hook', hook_action: 'update', token: token) }

      it 'does not run' do
        expect(subject.call).to be_nil
        expect(subject.filters_matched?).to be false
      end
    end

    context 'with GitHub "push" event for a tag' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
      end
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'push', hook_action: 'opened', token: token) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      it 'the workflow runs' do
        subject.call
        expect(subject.steps.first).to have_received(:call)
      end
    end

    context 'with GitLab "Tag Push Hook" event' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
      end
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'gitlab', hook_event: 'Tag Push Hook', hook_action: 'update', token: token) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      it 'the workflow runs' do
        subject.call
        expect(subject.steps.first).to have_received(:call)
      end
    end

    context 'with GitHub "pull_request" event matching the "merge_request" event filter alias' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }],
          'filters' => { 'event' => 'merge_request' } }
      end
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      context 'when no workflow version is provided' do
        it 'the workflow runs' do
          subject.call
          expect(subject.steps.first).to have_received(:call)
          expect(subject.filters_matched?).to be true
        end
      end

      context 'when a workflow version is provided that does not support the alias' do
        subject do
          described_class.new(workflow_instructions: yaml,
                              token: token, workflow_run: workflow_run, workflow_version_number: '1.0')
        end

        let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }

        it 'the workflow does not run' do
          subject.call
          expect(subject.steps.first).not_to have_received(:call)
        end
      end
    end

    context 'when the webhook event is against none of the branches in the branches/ignore filters' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }],
          'filters' => { 'branches' => { 'ignore' => %w[something main] } } }
      end
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      it 'the workflow runs' do
        subject.call
        expect(subject.steps.first).to have_received(:call)
        expect(subject.filters_matched?).to be true
      end
    end

    context 'when the webhook event is against none of the branches in the branches/only filters' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }],
          'filters' => { 'branches' => { 'only' => %w[something main] } } }
      end
      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token, request_payload: request_payload) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      it 'the workflow does not run' do
        subject.call
        expect(subject.steps.first).not_to have_received(:call)
        expect(subject.filters_matched?).to be false
      end
    end

    context 'when the webhook event is against one of the branches in the branches/ignore filters' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }],
          'filters' => { 'branches' => { 'ignore' => %w[something main] } } }
      end
      let(:request_payload) do
        {
          pull_request: {
            base: {
              ref: 'main'
            }
          }
        }.to_json
      end
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token, request_payload: request_payload) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      it 'the workflow does not run' do
        subject.call
        expect(subject.steps.first).not_to have_received(:call)
        expect(subject.filters_matched?).to be false
      end
    end

    context 'when the webhook event is against one of the branches in the branches/only filters' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }],
          'filters' => { 'branches' => { 'only' => %w[master develop] } } }
      end
      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token, request_payload: request_payload) }

      before do
        allow(subject.steps.first).to receive(:call)
      end

      it 'the workflow runs' do
        subject.call
        expect(subject.steps.first).to have_received(:call)
        expect(subject.filters_matched?).to be true
      end

      context 'the branches filter contains a number' do
        let(:yaml) do
          { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }],
            'filters' => { 'branches' => { 'only' => [16.0, 'develop'] } } }
        end
        let(:request_payload) { file_fixture('request_payload_github_pull_request_opened_branch_number.json').read }

        it 'the workflow runs' do
          subject.call
          expect(subject.steps.first).to have_received(:call)
          expect(subject.filters_matched?).to be true
        end
      end
    end

    context 'when filtering pull requests by label' do
      let(:token) { build(:workflow_token) }
      let(:yaml) { super().merge(filters: filters) }
      let(:scm_vendor) { 'github' }
      let(:workflow_run) { build(:workflow_run, token: token, scm_vendor: scm_vendor) }
      let(:step) { subject.steps.first }

      def run_pull_request(action, labels: [], changed_label: nil)
        payload = { action: action, pull_request: { labels: labels.map { |name| { name: name } } } }
        payload[:label] = { name: changed_label } if changed_label
        workflow_run.assign_attributes(hook_action: action, request_payload: payload.to_json)
        allow(step).to receive(:call)
        subject.call
      end

      context 'with labels.only' do
        let(:filters) { { event: 'pull_request', labels: { only: ['obs-build-images'] } } }

        it 'skips a newly opened pull request without labels' do
          run_pull_request('opened')
          expect(step).not_to have_received(:call)
        end

        it 'skips a new commit when none of the current labels match' do
          run_pull_request('synchronize', labels: ['documentation'])
          expect(step).not_to have_received(:call)
        end

        it 'runs on a new commit when one of the current labels matches' do
          run_pull_request('synchronize', labels: %w[documentation obs-build-images])
          expect(step).to have_received(:call)
        end

        it 'runs when the matching label is added' do
          run_pull_request('labeled', labels: %w[documentation obs-build-images], changed_label: 'obs-build-images')
          expect(step).to have_received(:call)
        end

        it 'ignores an unrelated addition even if the pull request has the matching label' do
          run_pull_request('labeled', labels: %w[obs-build-images documentation], changed_label: 'documentation')
          expect(step).not_to have_received(:call)
        end

        it 'runs cleanup for the matching label even though it is no longer on the pull request' do
          run_pull_request('unlabeled', labels: ['documentation'], changed_label: 'obs-build-images')
          expect(step).to have_received(:call)
        end

        it 'does not run cleanup when an unrelated label is removed' do
          run_pull_request('unlabeled', labels: ['obs-build-images'], changed_label: 'documentation')
          expect(step).not_to have_received(:call)
        end
      end

      context 'with labels.ignore on Gitea' do
        let(:scm_vendor) { 'gitea' }
        let(:filters) { { event: 'pull_request', labels: { ignore: ['skip-build'] } } }

        it 'skips a new commit if any current label is ignored' do
          run_pull_request('synchronized', labels: %w[documentation skip-build])
          expect(step).not_to have_received(:call)
        end

        it 'runs on a pull request opened without labels' do
          run_pull_request('opened')
          expect(step).to have_received(:call)
        end

        it 'ignores removal of an ignored label even when no labels remain' do
          run_pull_request('unlabeled', changed_label: 'skip-build')
          expect(step).not_to have_received(:call)
        end

        it 'runs when a non-ignored label is added' do
          run_pull_request('labeled', labels: ['documentation'], changed_label: 'documentation')
          expect(step).to have_received(:call)
        end
      end

      context 'without a labels filter' do
        let(:filters) { { event: 'pull_request' } }

        it 'does not run when a label is added' do
          run_pull_request('labeled', labels: ['documentation'], changed_label: 'documentation')
          expect(step).not_to have_received(:call)
        end

        it 'does not run cleanup when a label is removed' do
          run_pull_request('unlabeled', changed_label: 'documentation')
          expect(step).not_to have_received(:call)
        end
      end
    end

    context 'when the webhook event is not supported by the branches filter' do
      let(:yaml) do
        { 'steps' => [{ 'trigger_services' => { 'project' => 'test-project', 'package' => 'test-package' } }],
          'filters' => { 'branches' => { 'only' => ['develop'] } } }
      end
      let!(:workflow_run) { create(:workflow_run, scm_vendor: 'gitlab', hook_event: 'Tag Push Hook', hook_action: 'update', token: token) }

      it 'is not valid and has an error message' do
        subject.valid?(:call)
        expect(subject.errors.full_messages.to_sentence).to eq('Filters for branches are not supported for the tag push event. ' \
                                                               "Documentation for filters: #{WorkflowFiltersValidator::DOCUMENTATION_LINK}")
      end
    end
  end

  describe '#steps' do
    let(:project) { create(:project, name: 'test-project', maintainer: user) }
    let(:package) { create(:package, name: 'test-package', project: project) }
    let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
    let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token, request_payload: request_payload) }

    before do
      login user
    end

    context 'with a supported step' do
      let(:yaml) do
        { 'steps' => [{ branch_package: { source_project: project.name, source_package: package.name, target_project: project.name } }] }
      end

      it 'initializes the supported step objects' do
        expect(subject.steps.first).to be_a(Workflow::Step::BranchPackageStep)
      end

      # This example requires VCR
      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }
    end

    context 'with several supported steps' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: project.name,
                                              source_package: package.name,
                                              target_project: project.name } },
                      { 'branch_package' => { source_project: project.name,
                                              source_package: package.name,
                                              target_project: project.name } }] }
      end

      it 'returns an array with two items' do
        expect(subject.steps.count).to be 2
      end
    end

    context 'with one unsupported step' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => {} },
                      { 'branch_package' => { source_project: project.name,
                                              source_package: package.name,
                                              target_project: project.name } }] }
      end

      it 'returns an array with only one item' do
        expect(subject.steps.count).to be 1
      end

      # This example requires VCR
      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }
    end

    context 'with no steps specified' do
      let(:yaml) do
        {}
      end

      it 'returns an empty array' do
        expect(subject.steps).to be_empty
      end

      # This example requires VCR
      it { expect { subject.call }.not_to change(WorkflowArtifactsPerStep, :count) }
    end

    context 'with step with invalid intructions' do
      let(:yaml) do
        { 'steps' => [{ branch_package: { source_package: package.name, target_project: project.name } }] }
      end

      it 'initializes the supported step objects' do
        expect(subject.steps.first).to be_a(Workflow::Step::BranchPackageStep)
      end

      # This example requires VCR
      it { expect { subject.call }.not_to change(WorkflowArtifactsPerStep, :count) }
    end

    context 'with step with invalid project name' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: '0', # invalid project name
                                              source_package: package.name,
                                              target_project: project.name } }] }
      end

      it 'initializes the supported step objects' do
        expect(subject.steps.first).to be_a(Workflow::Step::BranchPackageStep)
      end

      # This example requires VCR
      it { expect { subject.call }.not_to change(WorkflowArtifactsPerStep, :count) }
    end
  end

  describe '#filters' do
    let!(:workflow_run) { create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened', token: token) }

    context 'with filters having valid values' do
      let(:yaml) do
        {
          'filters' => {
            'event' => 'push',
            'branches' => { 'only' => %w[master staging] }
          }
        }
      end

      it 'returns filters' do
        expect(subject.filters).to eq({ event: 'push',
                                        branches: { only: %w[master staging] } })
      end
    end

    context 'without filters' do
      let(:yaml) do
        {}
      end

      it 'returns nothing' do
        expect(subject.filters).to eq({})
      end
    end
  end
end
