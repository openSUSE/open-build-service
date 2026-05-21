RSpec.describe Workflows::ArtifactsCollector, type: :service do
  subject { described_class.new(workflow_run_id: workflow_run.id, step: step) }

  let(:user) { create(:confirmed_user) }
  let(:token) { create(:workflow_token, executor: user) }

  describe '#call' do
    context 'for a branch_package step' do
      let(:step) do
        Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions, workflow_run: workflow_run, token: token)
      end

      let(:step_instructions) do
        {
          source_project: 'home:Iggy',
          source_package: 'hello_world',
          target_project: 'home:Iggy:sandbox'
        }
      end

      context 'and pull_request event' do
        let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: 'home:Iggy:sandbox:openSUSE:repo123:PR-1',
            target_package: step_instructions[:source_package]
          }
        end

        let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload) }

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::BranchPackageStep')
        end
      end

      context 'and push for commit event' do
        let(:request_payload) { file_fixture('request_payload_github_push.json').read }

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-d1b6a25fb371902586974d922ff4789dd4ed7d2e'
          }
        end

        let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'push', request_payload: request_payload) }

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::BranchPackageStep')
        end
      end

      context 'and push for tag event' do
        let(:request_payload) { file_fixture('request_payload_github_tag_push.json').read }

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-v1'
          }
        end

        let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'push', request_payload: request_payload) }

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::BranchPackageStep')
        end
      end
    end

    context 'for a link_package step' do
      let(:step) do
        Workflow::Step::LinkPackageStep.new(step_instructions: step_instructions,
                                            workflow_run: workflow_run,
                                            token: token)
      end

      let(:step_instructions) do
        {
          source_project: 'home:Iggy',
          source_package: 'hello_world',
          target_project: 'home:Iggy:sandbox'
        }
      end

      context 'and pull_request event' do
        let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: 'home:Iggy:sandbox:openSUSE:repo123:PR-1',
            target_package: step_instructions[:source_package]
          }
        end

        let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload) }

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::LinkPackageStep')
        end
      end

      context 'and push for commit event' do
        let(:request_payload) { file_fixture('request_payload_github_push.json').read }

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-d1b6a25fb371902586974d922ff4789dd4ed7d2e'
          }
        end

        let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'push', request_payload: request_payload) }

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::LinkPackageStep')
        end
      end

      context 'and push for tag event' do
        let(:request_payload) { file_fixture('request_payload_github_tag_push.json').read }

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-v1'
          }
        end

        let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'push', request_payload: request_payload) }

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::LinkPackageStep')
        end
      end
    end

    context 'for a rebuild_package step' do
      let(:step) do
        Workflow::Step::RebuildPackage.new(step_instructions: step_instructions,
                                           workflow_run: workflow_run,
                                           token: token)
      end

      let(:step_instructions) do
        {
          project: 'home:Iggy',
          package: 'hello_world'
        }
      end

      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      let(:artifacts) { step_instructions }
      let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload) }

      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

      it do
        subject.call
        expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
        expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::RebuildPackage')
      end
    end

    context 'for a trigger_services step' do
      let(:step) do
        Workflow::Step::TriggerServices.new(step_instructions: step_instructions,
                                            workflow_run: workflow_run,
                                            token: token)
      end

      let(:step_instructions) do
        {
          project: 'home:Iggy',
          package: 'hello_world'
        }
      end

      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      let(:artifacts) { step_instructions }
      let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload) }

      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

      it do
        subject.call
        expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
        expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::TriggerServices')
      end
    end

    context 'for a configure_repositories step' do
      let(:step) do
        Workflow::Step::ConfigureRepositories.new(step_instructions: step_instructions,
                                                  workflow_run: workflow_run,
                                                  token: token)
      end

      let(:step_instructions) do
        {
          project: 'home:Iggy:sandbox',
          repositories:
            [
              {
                name: 'openSUSE_Tumbleweed',
                paths: [
                  {
                    target_project: 'openSUSE:Factory',
                    target_repository: 'snapshot'
                  }
                ],
                architectures: %w[
                  x86_64
                  ppc
                ]
              },
              {
                name: 'openSUSE_Leap_15.3',
                paths: [
                  { target_project: 'openSUSE:Leap:15.3',
                    target_repository: 'standard' }
                ],
                architectures: [
                  'x86_64'
                ]
              }
            ]
        }
      end

      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      let(:artifacts) do
        {
          project: 'home:Iggy:sandbox:openSUSE:repo123:PR-1',
          repositories: step_instructions[:repositories]
        }
      end

      let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload) }

      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

      it do
        subject.call
        expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
        expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::ConfigureRepositories')
      end
    end

    context 'for set_flag step' do
      let(:step) { Workflow::Step::SetFlags.new(step_instructions: step_instructions, workflow_run: workflow_run, token: token) }
      let(:step_instructions) do
        {
          flags: [
            { type: 'build', status: 'enable', project: 'home:Admin' }
          ]
        }
      end

      let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

      let(:artifacts) do
        {
          flags: step_instructions[:flags]
        }
      end

      let(:workflow_run) { create(:workflow_run, token: token, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload) }

      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

      it do
        subject.call
        expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
        expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::SetFlags')
      end
    end
  end
end
