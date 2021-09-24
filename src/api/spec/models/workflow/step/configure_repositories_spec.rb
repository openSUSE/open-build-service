require 'rails_helper'

RSpec.describe Workflow::Step::ConfigureRepositories do
  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, user: user) }

  describe '#call' do
    let(:project) { create(:project, name: 'openSUSE:Factory') }
    let!(:repository) { create(:repository, project: project, name: 'snapshot', architectures: ['i586', 'aarch64']) }
    let(:target_project_name) do
      'OBS:Server:Unstable:openSUSE-repo123:PR-1'
    end
    let(:target_project) { create(:project, name: target_project_name, maintainer: user) }
    let(:step_instructions) do
      {
        project: 'OBS:Server:Unstable',
        repositories:
          [
            {
              name: 'openSUSE_Tumbleweed',
              target_project: 'openSUSE:Factory',
              target_repository: 'snapshot',
              architectures: [
                'x86_64',
                'ppc'
              ]
            }
          ]
      }
    end
    let(:scm_webhook) do
      ScmWebhook.new(payload: {
                       scm: 'github',
                       event: 'pull_request',
                       action: 'opened',
                       pr_number: 1,
                       source_repository_full_name: 'openSUSE/repo123',
                       target_repository_full_name: 'openSUSE/repo123',
                       commit_sha: '123'
                     })
    end
    let(:workflow_filters) do
      { architectures: { only: ['x86_64', 'ppc'] }, repositories: { ignore: ['openSUSE_Tumbleweed'] } }
    end

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token)
    end

    context 'when the token user does not have enough permissions' do
      let(:another_user) { create(:confirmed_user, :with_home, login: 'Pop') }
      let(:token) { create(:workflow_token, user: another_user) }
      let(:scm_webhook) do
        ScmWebhook.new(payload: {
                         scm: 'github',
                         event: 'pull_request',
                         action: 'opened',
                         pr_number: 1,
                         target_repository_full_name: 'openSUSE/repo123',
                         commit_sha: '123'
                       })
      end

      before do
        target_project
        project
        login(another_user)
      end

      it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
    end

    context 'when the target branch project is present' do
      before do
        target_project
        project
        login(user)
      end

      context 'and we have all the required properties in the configuration file' do
        before do
          subject.call({ workflow_filters: workflow_filters })
        end

        let(:configured_repositories) { target_project.reload.repositories }
        let(:configured_path_elements) { configured_repositories.first.path_elements }
        let(:configured_architectures) { configured_repositories.first.architectures }

        it 'configures the repository with the right attributes' do
          expect(configured_repositories.count).to eq(1)
          expect(configured_repositories.first).to have_attributes(name: 'openSUSE_Tumbleweed', db_project_id: target_project.id)
        end

        it 'configures the path element with the right attributes' do
          expect(configured_path_elements.count).to eq(1)
          expect(configured_path_elements.first).to have_attributes(parent_id: configured_repositories.first.id,
                                                                    repository_id: repository.id,
                                                                    position: 1, kind: 'standard')
        end

        it 'overwriting previously configured architectures with those in the step instructions' do
          expect(configured_architectures.map(&:name)).to eq(['x86_64', 'ppc'])
        end
      end

      context 'and there is no source project in the configuration file' do
        let(:step_instructions) do
          {
            fake_project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  target_project: 'openSUSE:Factory',
                  target_repository: 'snapshot',
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        it { expect(subject).not_to be_valid }

        it 'does not create any repository' do
          expect { subject.call({}) }.not_to change(Repository, :count)
        end

        it 'does not create any architecture' do
          expect { subject.call({}) }.not_to change(Architecture, :count)
        end

        it 'a validation fails complaining about a missing project' do
          subject.call
          expect(subject.errors.full_messages).to include("The 'project' key is missing")
        end
      end

      context 'and there is no target project defined in the repository definition' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  target_repository: 'snapshot',
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        it 'is not valid due to a missing target project' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq('configure_repositories step: All repositories must have the ' \
                                                                 "'architectures', 'name', 'target_project', and 'target_repository' keys")
        end
      end

      context 'and there is no target repository in the repository definition' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  target_project: 'openSUSE:Factory',
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        it 'is not valid due to a missing target repository' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq('configure_repositories step: All repositories must have the ' \
                                                                 "'architectures', 'name', 'target_project', and 'target_repository' keys")
        end
      end

      context 'and the target repository already exist in the database' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  target_project: 'openSUSE:Factory',
                  target_repository: 'snapshot',
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        before do
          create(:repository, name: 'openSUSE_Tumbleweed', project: target_project)
        end

        it 'does not create the repository again' do
          expect { subject.call }.not_to change(Repository, :count)
        end
      end

      context 'and there are no architectures in the repository definition' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  target_project: 'openSUSE:Factory',
                  target_repository: 'snapshot'
                }
              ]
          }
        end

        it 'is not valid due to the missing architectures' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq('configure_repositories step: All repositories must have the ' \
                                                                 "'architectures', 'name', 'target_project', and 'target_repository' keys")
        end
      end

      context "and the architectures in the repository definition don't exist" do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed-snapshot',
                  target_project: 'openSUSE:Factory',
                  target_repository: 'snapshot',
                  architectures: [
                    'foo',
                    'x86_64'
                  ]
                },
                {
                  name: 'openSUSE_Tumbleweed-standard',
                  target_project: 'openSUSE:Factory',
                  target_repository: 'standard',
                  architectures: [
                    'bar',
                    'i586'
                  ]
                }

              ]
          }
        end

        it 'is not valid due to an inexistent architecture' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq("configure_repositories step: Architectures 'foo' and 'bar' do not exist")
        end
      end
    end

    context 'when there is no target project in the database' do
      let(:step_instructions) do
        {
          project: 'OBS:Server:Unstable',
          repositories:
            [
              {
                name: 'openSUSE_Tumbleweed',
                target_project: 'openSUSE:Factory',
                target_repository: 'snapshot',
                architectures: [
                  'x86_64',
                  'ppc'
                ]
              }
            ]
        }
      end

      before do
        project
        login(user)
      end

      it 'raises an error due to an inexistent target project' do
        expect { subject.call }.to raise_error(Project::Errors::UnknownObjectError, "Project not found: #{target_project_name}")
      end
    end
  end

  describe '#target_project_name' do
    let(:step_instructions) do
      {
        project: 'OBS:Server:Unstable',
        repositories:
          [
            {
              name: 'openSUSE_Tumbleweed',
              target_project: 'openSUSE:Factory',
              target_repository: 'snapshot',
              architectures: [
                'x86_64',
                'ppc'
              ]
            }
          ]
      }
    end
    let(:scm_webhook) { ScmWebhook.new(payload: payload) }

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token).target_project_name
    end

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

        it { is_expected.to eq('OBS:Server:Unstable:openSUSE-repo123:PR-1') }
      end

      context 'from GitLab' do
        let(:payload) do
          {
            scm: 'gitlab',
            event: 'Merge Request Hook',
            pr_number: 1,
            path_with_namespace: 'openSUSE/repo123'
          }
        end

        it { is_expected.to eq('OBS:Server:Unstable:openSUSE-repo123:PR-1') }
      end
    end

    context 'for a push webhook event' do
      context 'from GitHub' do
        let(:payload) { { scm: 'github', event: 'push' } }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end

      context 'from GitLab' do
        let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }

        it { is_expected.to eq('OBS:Server:Unstable') }
      end
    end
  end
end
