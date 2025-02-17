RSpec.describe Workflow::Step::ConfigureRepositories do
  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }

  describe '#call' do
    subject do
      described_class.new(step_instructions: step_instructions,
                          token: token,
                          workflow_run: workflow_run)
    end

    let(:path_project1) { create(:project, name: 'openSUSE:Factory') }
    let!(:path_repository1) { create(:repository, project: path_project1, name: 'snapshot', architectures: %w[i586 aarch64]) }
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
              architectures: %w[
                x86_64
                ppc
              ]
            }
          ]
      }
    end

    let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

    let(:workflow_run) do
      create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload)
    end

    context 'when the token user does not have enough permissions' do
      let(:another_user) { create(:confirmed_user, :with_home, login: 'Pop') }
      let(:token) { create(:workflow_token, executor: another_user) }

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
          expect(configured_repositories).to contain_exactly(have_attributes(name: 'openSUSE_Tumbleweed', db_project_id: target_project.id))
        end

        it 'configures the path elements with the right attributes' do
          expect(configured_path_elements).to contain_exactly(
            have_attributes(parent_id: configured_repositories.first.id, repository_id: path_repository1.id, position: 1, kind: 'standard'),
            have_attributes(parent_id: configured_repositories.first.id, repository_id: path_repository2.id, position: 2, kind: 'standard')
          )
        end

        it 'overwrites previously configured architectures with those in the step instructions' do
          expect(configured_architectures.map(&:name)).to eq(%w[x86_64 ppc])
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
                  architectures: %w[
                    x86_64
                    ppc
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
                                                      'https://openbuildservice.org/help/manuals/obs-user-guide/cha-obs-scm-ci-workflow-integration' \
                                                      '#sec-obs-obs-scm-ci-workflow-integration-obs-workflows-steps-configure-repositories-architectures-for-a-project ' \
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
                  architectures: %w[
                    x86_64
                    ppc
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
                  architectures: %w[
                    x86_64
                    ppc
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
                  architectures: %w[
                    x86_64
                    ppc
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
                  architectures: %w[
                    foo
                    x86_64
                  ]
                },
                {
                  name: 'openSUSE_Tumbleweed-standard',
                  paths: [{ target_project: 'openSUSE:Factory', target_repository: 'standard' }],
                  architectures: %w[
                    bar
                    i586
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
                architectures: %w[
                  x86_64
                  ppc
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
end
