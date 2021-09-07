require 'rails_helper'

RSpec.describe Workflow::Step::ConfigureRepositories do
  # FIXME: This isn't only testing #call, it's also testing custom validations.
  describe '#call' do
    let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
    let(:token) { create(:workflow_token, user: user) }
    let(:project) { create(:project, name: 'openSUSE:Factory', maintainer: user) }
    let!(:repository) { create(:repository, project: project, name: 'snapshot', architectures: ['i586', 'aarch64']) }
    let(:target_project_name) do
      'home:Iggy:OBS:Server:Unstable:PR-1'
    end
    let(:target_project) { create(:project, name: target_project_name) }
    let(:step_instructions) do
      {
        source_project: 'OBS:Server:Unstable',
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
                       action: action,
                       pr_number: 1,
                       source_repository_full_name: 'reponame',
                       commit_sha: '123'
                     })
    end

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token)
    end

    context 'for all supported pull request actions' do
      ScmWebhookEventValidator::ALLOWED_PULL_REQUEST_ACTIONS.each do |pull_request_action|
        let(:action) { pull_request_action }

        context 'when the target branch project is present' do
          before do
            target_project
            login(user)
          end

          context 'and there is no source project in the configuration file' do
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

            it { expect(subject).not_to be_valid }

            it 'does not create/destroy any repository' do
              expect { subject.call }.not_to change(Repository, :count)
            end

            it 'does not create/destroy any architecture' do
              expect { subject.call }.not_to change(Architecture, :count)
            end

            it 'a validation fails complaining about a missing source project' do
              subject.call
              expect(subject.errors.full_messages).to include("Source project name can't be blank")
            end
          end

          context 'and there is no target project defined in the repository definition' do
            let(:step_instructions) do
              {
                source_project: 'OBS:Server:Unstable',
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
                source_project: 'OBS:Server:Unstable',
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
                source_project: 'OBS:Server:Unstable',
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

            it 'does not create/destroy any repository' do
              expect { subject.call }.not_to change(Repository, :count)
            end
          end

          context 'and there are no architectures in the repository definition' do
            let(:step_instructions) do
              {
                source_project: 'OBS:Server:Unstable',
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
                source_project: 'OBS:Server:Unstable',
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
              source_project: 'OBS:Server:Unstable',
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
            login(user)
          end

          it 'raises an error due to an inexistent target project' do
            expect { subject.call }.to raise_error(Project::Errors::UnknownObjectError, 'Project not found: home:Iggy:OBS:Server:Unstable:PR-1')
          end
        end
      end
    end

    context 'for a closed/merged pull request' do
      let(:action) { 'closed' }
      let(:repository_instructions) { step_instructions[:repositories].first }

      context 'when the target branch project is present' do
        before do
          target_project
          login(user)

          # Recreating repositories, its architectures and path elements as if the step already ran before
          create(:repository, name: repository_instructions[:name],
                              project: target_project,
                              architectures: repository_instructions[:architectures],
                              path_element_link: repository)
        end

        context 'and we have all the required properties in the configuration file' do
          it 'destroys the repository, its architectures and path elements' do
            expect { subject.call }.to change(Repository, :count).by(-1)
                                                                 .and(change(RepositoryArchitecture, :count).by(-2))
                                                                 .and(change(PathElement, :count).by(-1))
          end
        end
      end
    end

    ['opened', 'synchronize', 'reopened'].each do |pull_request_action|
      context "for a pull request with the action '#{pull_request_action}'" do
        let(:action) { pull_request_action }

        context 'when the target branch project is present' do
          before do
            target_project
            login(user)
          end

          context 'and we have all the required properties in the configuration file' do
            before do
              subject.call
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
        end
      end
    end
  end
end
