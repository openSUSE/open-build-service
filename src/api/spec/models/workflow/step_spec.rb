RSpec.describe Workflow::Step do
  describe '#target_package_name' do
    subject { described_class.new(step_instructions: step_instructions, workflow_run: workflow_run).send(:target_package_name) }

    let(:workflow_run) do
      create(:workflow_run, scm_vendor: scm_vendor, hook_event: hook_event, request_payload: request_payload)
    end

    let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

    context 'for a pull request_event when target_package is in the step instructions' do
      let(:step_instructions) { { target_package: 'hello_world' } }
      let(:hook_event) { 'pull_request' }
      let(:scm_vendor) { 'github' }

      it 'returns the value of target_package' do
        expect(subject).to eq('hello_world')
      end
    end

    context 'for a pull request_event when target_package is not in the step instructions' do
      let(:step_instructions) { { source_package: 'package123' } }
      let(:hook_event) { 'pull_request' }
      let(:scm_vendor) { 'github' }

      it 'returns the name of the source package' do
        expect(subject).to eq('package123')
      end
    end

    context 'with a push event for a commit when target_package is in the step instructions' do
      let(:step_instructions) { { target_package: 'hello_world' } }
      let(:hook_event) { 'push' }
      let(:scm_vendor) { 'github' }

      let(:request_payload) do
        {
          ref: 'refs/heads/main',
          after: '456',
          repository: {
            full_name: 'openSUSE/open-build-service'
          }
        }.to_json
      end

      it 'returns the value of target_package with the commit SHA as a suffix' do
        expect(subject).to eq('hello_world-456')
      end
    end

    context 'with a push event for a commit when target_package is not in the step instructions' do
      let(:step_instructions) { { source_package: 'package123' } }
      let(:hook_event) { 'push' }
      let(:scm_vendor) { 'github' }

      let(:request_payload) do
        {
          ref: 'refs/heads/main',
          after: '456',
          repository: {
            full_name: 'openSUSE/open-build-service'
          }
        }.to_json
      end

      it 'returns the name of the source package with the commit SHA as a suffix' do
        expect(subject).to eq('package123-456')
      end
    end

    context 'with a push event for a tag when target_package is in the step instructions' do
      let(:step_instructions) { { target_package: 'hello_world' } }
      let(:hook_event) { 'push' }
      let(:scm_vendor) { 'github' }

      let(:request_payload) do
        {
          ref: 'refs/tags/release_abc',
          after: '456',
          repository: {
            full_name: 'openSUSE/open-build-service'
          }
        }.to_json
      end

      it 'returns the value of target_package with the tag name as a suffix' do
        expect(subject).to eq('hello_world-release_abc')
      end
    end

    context 'with a push event for a tag when target_package is not in the step instructions' do
      let(:step_instructions) { { source_package: 'package123' } }
      let(:hook_event) { 'push' }
      let(:scm_vendor) { 'github' }

      let(:request_payload) do
        {
          ref: 'refs/tags/release_abc',
          after: '456',
          repository: {
            full_name: 'openSUSE/open-build-service'
          }
        }.to_json
      end

      it 'returns the name of the source package with the tag name as a suffix' do
        expect(subject).to eq('package123-release_abc')
      end
    end
  end

  describe '#target_project_name' do
    subject do
      step.new(step_instructions: step_instructions, workflow_run: workflow_run).target_project_name
    end

    let(:workflow_run) do
      create(:workflow_run, scm_vendor: scm_vendor, hook_event: hook_event, hook_action: hook_action, request_payload: request_payload)
    end
    let(:hook_action) { 'opened' }
    let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

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

    context 'for a pull request webhook event' do
      context 'from GitHub' do
        let(:hook_event) { 'pull_request' }
        let(:scm_vendor) { 'github' }

        it { is_expected.to eq('OBS:Server:Unstable:openSUSE:repo123:PR-1') }
      end

      context 'from GitLab' do
        let(:hook_event) { 'Merge Request Hook' }
        let(:scm_vendor) { 'gitlab' }
        let(:hook_action) { 'open' }

        let(:request_payload) { file_fixture('request_payload_gitlab_pull_request_opened.json').read }

        it { is_expected.to eq('OBS:Server:Unstable:gitlabhq:gitlab-test:PR-1') }
      end
    end

    context 'with a push webhook event for a commit' do
      context 'from GitHub' do
        let(:hook_event) { 'push' }
        let(:scm_vendor) { 'github' }
        let(:request_payload) do
          {
            ref: 'refs/heads/branch_123'
          }.to_json
        end

        it { is_expected.to eq('OBS:Server:Unstable') }
      end

      context 'from GitLab' do
        let(:hook_event) { 'Push Hook' }
        let(:scm_vendor) { 'gitlab' }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end
    end

    context 'with a push webhook event for a tag' do
      context 'from GitHub' do
        let(:hook_event) { 'push' }
        let(:scm_vendor) { 'github' }
        let(:request_payload) do
          {
            ref: 'refs/tags/release_abc'
          }.to_json
        end

        it { is_expected.to eq('OBS:Server:Unstable') }
      end

      context 'from GitLab' do
        let(:hook_event) { 'Tag Push Hook' }
        let(:scm_vendor) { 'gitlab' }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end
    end
  end

  describe '#create_target_project' do
    subject { step.send(:create_target_project) }

    let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
    let(:token) { create(:workflow_token, executor: user) }
    # The executor is allowed to create the target project because they maintain its parent project
    let!(:parent_project) { create(:project, name: 'target_project', maintainer: user) }
    let(:workflow_run) do
      create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', hook_action: 'opened',
                            request_payload: file_fixture('request_payload_github_pull_request_opened.json').read)
    end
    let(:step_instructions) do
      { source_project: 'source_project', source_package: 'source_package', target_project: parent_project.name }
    end
    let(:step) { step_class.new(step_instructions: step_instructions, token: token, workflow_run: workflow_run) }

    before do
      login(user)
    end

    # All the steps creating a target project share the implementation of the parent class,
    # they only differ in the step name they put into the commit comment.
    { Workflow::Step::LinkProject => 'link_project',
      Workflow::Step::BranchPackageStep => 'branch_package',
      Workflow::Step::LinkPackageStep => 'link_package' }.each do |klass, step_name|
      context "in a #{step_name} step" do
        let(:step_class) { klass }

        context 'when the target project does not exist yet' do
          it 'creates it' do
            expect { subject }.to change(Project, :count).by(1)
          end

          it 'names it after the target project of the step instructions and the pull request' do
            expect(subject.name).to eq('target_project:openSUSE:repo123:PR-1')
          end

          it 'sets its url to the url of the event source' do
            expect(subject.url).to eq('http://github.com/something')
          end

          it 'makes the executor of the token a maintainer of it' do
            expect(subject.maintainers).to eq([user])
          end

          context 'storing it' do
            let(:new_project) { Project.new(name: step.target_project_name, url: workflow_run.event_source_url) }

            before do
              # Project.new is also called by the create? policy, so we only replace the one call we care about
              allow(Project).to receive(:new).and_call_original
              allow(Project).to receive(:new).with(name: new_project.name, url: new_project.url).and_return(new_project)
              allow(new_project).to receive(:store).and_call_original

              subject
            end

            it 'mentions the step in the commit comment' do
              expect(new_project).to have_received(:store).with(comment: "SCM/CI integration, #{step_name} step")
            end
          end
        end

        context 'when the target project already exists' do
          let!(:existing_target_project) { create(:project, name: step.target_project_name, maintainer: user) }

          it 'returns it' do
            expect(subject).to eq(existing_target_project)
          end

          it 'does not create another project' do
            expect { subject }.not_to change(Project, :count)
          end
        end
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
