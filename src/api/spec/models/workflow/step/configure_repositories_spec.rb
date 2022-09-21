require 'rails_helper'

RSpec.describe Workflow::Step::ConfigureRepositories do
  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }

  describe '#call' do
    let(:path_project1) { create(:project, name: 'openSUSE:Factory') }
    let!(:path_repository1) { create(:repository, project: path_project1, name: 'snapshot', architectures: ['i586', 'aarch64']) }
    let(:path_project2) { create(:project, name: 'openSUSE:Leap:15.4') }
    let!(:path_repository2) { create(:repository, project: path_project2, name: 'standard', architectures: ['x86_64']) }
    let(:target_project) { create(:project, name: 'OBS:Server:Unstable:openSUSE:repo123:PR-1', maintainer: user) }
    let(:step_instructions) do
      {
        project: 'OBS:Server:Unstable',
        repositories:
          [
            {
              name: 'openSUSE_Tumbleweed',
              paths: [
                { target_project: 'openSUSE:Factory', target_repository: 'snapshot' },
                { target_project: 'openSUSE:Leap:15.4', target_repository: 'standard' }
              ],
              architectures: [
                'x86_64',
                'ppc'
              ]
            }
          ]
      }
    end
    let(:scm_webhook) do
      SCMWebhook.new(payload: {
                       scm: 'github',
                       event: 'pull_request',
                       action: 'opened',
                       pr_number: 1,
                       source_repository_full_name: 'openSUSE/repo123',
                       target_repository_full_name: 'openSUSE/repo123',
                       commit_sha: '123'
                     })
    end

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token)
    end

    context 'when the token user does not have enough permissions' do
      let(:another_user) { create(:confirmed_user, :with_home, login: 'Pop') }
      let(:token) { create(:workflow_token, executor: another_user) }
      let(:scm_webhook) do
        SCMWebhook.new(payload: {
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
        login(another_user)
      end

      it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
    end

    context 'when the target branch project is present' do
      before do
        target_project
        login(user)
      end

      context 'and we have all the required keys in the step instructions' do
        before do
          subject.call
        end

        let(:configured_repositories) { target_project.reload.repositories }
        let(:configured_path_elements) { configured_repositories.first.path_elements }
        let(:configured_architectures) { configured_repositories.first.architectures }

        it 'configures the repository with the right attributes' do
          expect(configured_repositories).to match_array([
                                                           have_attributes(name: 'openSUSE_Tumbleweed', db_project_id: target_project.id)
                                                         ])
        end

        it 'configures the path elements with the right attributes' do
          expect(configured_path_elements).to match_array([
                                                            have_attributes(parent_id: configured_repositories.first.id, repository_id: path_repository1.id, position: 1,
                                                                            kind: 'standard'),
                                                            have_attributes(parent_id: configured_repositories.first.id, repository_id: path_repository2.id, position: 2, kind: 'standard')
                                                          ])
        end

        it 'overwrites previously configured architectures with those in the step instructions' do
          expect(configured_architectures.map(&:name)).to eq(['x86_64', 'ppc'])
        end
      end

      context 'and the project is missing in the step instructions' do
        let(:step_instructions) do
          {
            fake_project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' }],
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
          expect { subject.call }.not_to change(Repository, :count)
        end

        it 'does not create any architecture' do
          expect { subject.call }.not_to change(Architecture, :count)
        end

        it "a validation fails complaining about the missing 'project' key" do
          subject.call
          expect(subject.errors.full_messages.to_sentence).to eq("The 'project' key is missing")
        end
      end

      context 'and repository paths are missing in the step instructions' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        # rubocop:disable RSpec/ExampleLength
        # This will be fixed once we remove the temporary error message helping users migrate their configure_repositories steps
        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to eq(["configure_repositories step: Repository paths are now set under the 'paths' key. Refer to " \
                                                      'https://openbuildservice.org/help/manuals/obs-user-guide/cha.obs.scm_ci_workflow_integration.html' \
                                                      '#sec.obs.obs_scm_ci_workflow_integration.obs_workflows.steps.configure_repositories_architectures_for_a_project ' \
                                                      'for an example',
                                                      "configure_repositories step: All repositories must have the 'architectures', 'name', and 'paths' keys",
                                                      "configure_repositories step: All repository paths must have the 'target_project' and 'target_repository' keys"])
        end
        # rubocop:enable RSpec/ExampleLength
      end

      context 'and at least one repository path is missing a target project in the step instructions' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  paths: [
                    { target_repository: 'snapshot' },
                    { target_project: 'openSUSE:Factory', target_repository: 'snapshot' }
                  ],
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq('configure_repositories step: All repository paths must have the ' \
                                                                 "'target_project' and 'target_repository' keys")
        end
      end

      context 'and at least one repository path is missing a target repository in the step instructions' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  paths: [
                    { target_project: 'openSUSE:Factory' },
                    { target_project: 'openSUSE:Factory', target_repository: 'snapshot' }
                  ],
                  architectures: [
                    'x86_64',
                    'ppc'
                  ]
                }
              ]
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq('configure_repositories step: All repository paths must have the ' \
                                                                 "'target_project' and 'target_repository' keys")
        end
      end

      context 'and the target repository of the repository path already exists in the database' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' }],
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

        it 'does not recreate the repository' do
          expect { subject.call }.not_to change(Repository, :count)
        end
      end

      context 'and the repository is missing architectures in the step instructions' do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed',
                  paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' }]
                }
              ]
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq('configure_repositories step: All repositories must have the ' \
                                                                 "'architectures', 'name', and 'paths' keys")
        end
      end

      context "and the repository's architectures don't exist" do
        let(:step_instructions) do
          {
            project: 'OBS:Server:Unstable',
            repositories:
              [
                {
                  name: 'openSUSE_Tumbleweed-snapshot',
                  paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' }],
                  architectures: [
                    'foo',
                    'x86_64'
                  ]
                },
                {
                  name: 'openSUSE_Tumbleweed-standard',
                  paths: [{ target_project: 'openSUSE:Factory', target_repository: 'standard' }],
                  architectures: [
                    'bar',
                    'i586'
                  ]
                }

              ]
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.to_sentence).to eq("configure_repositories step: Architectures 'foo' and 'bar' do not exist")
        end
      end
    end

    context 'when the target project does not exist' do
      let(:step_instructions) do
        {
          project: 'OBS:Server:Unstable',
          repositories:
            [
              {
                name: 'openSUSE_Tumbleweed',
                paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' }],
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

      it 'raises an error' do
        expect { subject.call }.to raise_error(Project::Errors::UnknownObjectError, "Project not found: #{subject.target_project_name}")
      end
    end
  end

  describe '#validate_project_name' do
    let(:step_instructions) do
      {
        project: 'Invalid/format',
        repositories:
          [
            {
              name: 'openSUSE_Tumbleweed',
              paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' }],
              architectures: [
                'x86_64',
                'ppc'
              ]
            }
          ]
      }
    end
    let(:scm_webhook) { SCMWebhook.new(payload: payload) }

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token)
    end

    context 'when the source project is invalid' do
      let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }

      it 'adds a validation error' do
        subject.valid?

        expect { subject.call }.not_to change(Package, :count)
        expect(subject.errors.full_messages.to_sentence).to eq("Invalid project 'Invalid/format'")
      end
    end
  end
end
