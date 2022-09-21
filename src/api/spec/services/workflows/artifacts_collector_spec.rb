require 'rails_helper'

RSpec.describe Workflows::ArtifactsCollector, type: :service do
  let(:user) { create(:confirmed_user) }
  let(:token) { create(:workflow_token, executor: user) }
  let(:workflow_run) { create(:workflow_run, token: token) }

  subject { described_class.new(workflow_run_id: workflow_run.id, step: step) }

  describe '#call' do
    context 'for a branch_package step' do
      let(:step) do
        Workflow::Step::BranchPackageStep.new(step_instructions: step_instructions,
                                              scm_webhook: scm_webhook,
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
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'pull_request',
                           pr_number: 1,
                           target_branch: 'master',
                           action: 'opened',
                           source_repository_full_name: 'iggy/hello_world',
                           target_repository_full_name: 'iggy/hello_world'
                         })
        end

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: 'home:Iggy:sandbox:iggy:hello_world:PR-1',
            target_package: step_instructions[:source_package]
          }
        end

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::BranchPackageStep')
        end
      end

      context 'and push for commit event' do
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'push',
                           target_branch: 'main',
                           source_repository_full_name: 'iggy/hello_world',
                           commit_sha: '2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc',
                           target_repository_full_name: 'iggy/hello_world',
                           ref: 'refs/heads/branch_123'
                         })
        end

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc'
          }
        end

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::BranchPackageStep')
        end
      end

      context 'and push for tag event' do
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'push',
                           target_branch: '2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc',
                           source_repository_full_name: 'iggy/hello_world',
                           commit_sha: '2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc',
                           target_repository_full_name: 'iggy/hello_world',
                           tag_name: 'release_abc',
                           ref: 'refs/tags/release_abc'
                         })
        end

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-release_abc'
          }
        end

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
                                            scm_webhook: scm_webhook,
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
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'pull_request',
                           pr_number: 1,
                           target_branch: 'master',
                           action: 'opened',
                           source_repository_full_name: 'iggy/hello_world',
                           target_repository_full_name: 'iggy/hello_world'
                         })
        end

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: 'home:Iggy:sandbox:iggy:hello_world:PR-1',
            target_package: step_instructions[:source_package]
          }
        end

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::LinkPackageStep')
        end
      end

      context 'and push for commit event' do
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'push',
                           target_branch: 'main',
                           source_repository_full_name: 'iggy/hello_world',
                           commit_sha: '2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc',
                           target_repository_full_name: 'iggy/hello_world',
                           ref: 'refs/heads/branch_123'
                         })
        end

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc'
          }
        end

        it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

        it do
          subject.call
          expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
          expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::LinkPackageStep')
        end
      end

      context 'and push for tag event' do
        let(:scm_webhook) do
          SCMWebhook.new(payload: {
                           scm: 'github',
                           event: 'push',
                           target_branch: '2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc',
                           source_repository_full_name: 'iggy/hello_world',
                           commit_sha: '2a6b530bcdf7a54d881c62333c9f13b6ce16f3fc',
                           target_repository_full_name: 'iggy/hello_world',
                           tag_name: 'release_abc',
                           ref: 'refs/tags/release_abc'
                         })
        end

        let(:artifacts) do
          {
            source_project: step_instructions[:source_project],
            source_package: step_instructions[:source_package],
            target_project: step_instructions[:target_project],
            target_package: 'hello_world-release_abc'
          }
        end

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
                                           scm_webhook: scm_webhook,
                                           token: token)
      end

      let(:step_instructions) do
        {
          project: 'home:Iggy',
          package: 'hello_world'
        }
      end

      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'pull_request',
                         pr_number: 1,
                         target_branch: 'master',
                         action: 'opened',
                         source_repository_full_name: 'iggy/hello_world',
                         target_repository_full_name: 'iggy/hello_world'
                       })
      end

      let(:artifacts) { step_instructions }

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
                                            scm_webhook: scm_webhook,
                                            token: token)
      end

      let(:step_instructions) do
        {
          project: 'home:Iggy',
          package: 'hello_world'
        }
      end

      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'pull_request',
                         pr_number: 1,
                         target_branch: 'master',
                         action: 'opened',
                         source_repository_full_name: 'iggy/hello_world',
                         target_repository_full_name: 'iggy/hello_world'
                       })
      end

      let(:artifacts) { step_instructions }

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
                                                  scm_webhook: scm_webhook,
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
                architectures: [
                  'x86_64',
                  'ppc'
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

      let(:scm_webhook) do
        SCMWebhook.new(payload: {
                         scm: 'github',
                         event: 'pull_request',
                         pr_number: 1,
                         target_branch: 'master',
                         action: 'opened',
                         source_repository_full_name: 'iggy/hello_world',
                         target_repository_full_name: 'iggy/hello_world'
                       })
      end

      let(:artifacts) do
        {
          project: 'home:Iggy:sandbox:iggy:hello_world:PR-1',
          repositories: step_instructions[:repositories]
        }
      end

      it { expect { subject.call }.to change(WorkflowArtifactsPerStep, :count).by(1) }

      it do
        subject.call
        expect(WorkflowArtifactsPerStep.last.artifacts).to eq(artifacts.to_json)
        expect(WorkflowArtifactsPerStep.last.step).to eq('Workflow::Step::ConfigureRepositories')
      end
    end
  end
end
