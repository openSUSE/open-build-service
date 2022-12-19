require 'rails_helper'

RSpec.describe Workflow::Step::SetFlags do
  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }

  describe '#call' do
    let(:step_instructions) do
      {
        flags:
          [
            {
              type: 'build',
              status: 'enable',
              project: 'home:Iggy',
              repository: 'openSUSE_Tumbleweed',
              architecture: 'x86_64'
            }
          ]
      }
    end
    let!(:target_project) { create(:project, name: 'home:Iggy:openSUSE:repo123:PR-1') }

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token)
    end

    context 'when the token user does not have enough permissions' do
      let(:another_user) { create(:confirmed_user, :with_home, login: 'Pop') }
      let(:token) { create(:workflow_token, executor: another_user) }
      let!(:project) { create(:project, name: 'home:Iggy') }
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
        login(another_user)
      end

      it {
        expect do
          subject.call
        rescue StandardError
          Pundit::NotAuthorizedError
        end.not_to change(Flag, :count)
      }
    end

    context 'when user have the permissions and the project is valid' do
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

      context 'when one flag is given' do
        it 'adds flag to the project' do
          expect { subject.call }.to change(Flag, :count).by(1)
          expect(Flag.all).to match_array([have_attributes(status: 'enable', repo: 'openSUSE_Tumbleweed', project_id: target_project.id, package_id: nil, flag: 'build')])
        end
      end

      context 'when multiple flags are given' do
        let(:step_instructions) do
          {
            flags:
              [
                {
                  type: 'build',
                  status: 'enable',
                  project: 'home:Iggy',
                  repository: 'openSUSE_Tumbleweed',
                  architecture: 'x86_64'
                },
                {
                  type: 'publish',
                  status: 'enable',
                  project: 'home:Iggy'
                }
              ]
          }
        end

        it 'add flags to the project' do
          expect { subject.call }.to change(Flag, :count).by(2)
          expect(Flag.all).to match_array([
                                            have_attributes(status: 'enable', repo: 'openSUSE_Tumbleweed', project_id: target_project.id, package_id: nil, flag: 'build'),
                                            have_attributes(status: 'enable', project_id: target_project.id, package_id: nil, flag: 'publish')
                                          ])
        end
      end
    end

    context 'when user have the permission and the package is valid' do
      let!(:target_package) { create(:package, commit_user: user, project: user.home_project, name: 'ctris-0087aa5c0549a6cc0b4c1bb324d2fa8dc665e063') }
      let(:payload) { { scm: 'gitlab', event: 'Push Hook', commit_sha: '0087aa5c0549a6cc0b4c1bb324d2fa8dc665e063' } }
      let(:scm_webhook) { SCMWebhook.new(payload: payload) }
      let(:step_instructions) do
        {
          flags:
            [
              {
                type: 'lock',
                status: 'disable',
                project: 'home:Iggy',
                package: 'ctris'
              }
            ]
        }
      end

      before do
        login(user)
      end

      it 'add flags to the package' do
        expect { subject.call }.to change(Flag, :count).by(1)
        expect(Flag.all).to match_array([
                                          have_attributes(status: 'disable', project_id: nil, package_id: target_package.id, flag: 'lock')
                                        ])
      end
    end

    context 'when there is a duplicate flag' do
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
      let(:step_instructions) do
        {
          flags:
            [
              {
                type: 'build',
                status: 'enable',
                project: 'home:Iggy',
                repository: 'openSUSE_Tumbleweed',
                architecture: 'x86_64'
              }
            ]
        }
      end

      before do
        target_project.add_flag('build', 'enable', 'openSUSE_Tumbleweed', 'x86_64')
        target_project.save!
      end

      it 'does not raise an error' do
        expect { subject.call }.not_to(change(Flag, :count))
        expect(Flag.all).to match_array([
                                          have_attributes(status: 'enable', repo: 'openSUSE_Tumbleweed', project_id: target_project.id, package_id: nil, flag: 'build')
                                        ])
      end
    end

    context 'when the flag exists but the status differs' do
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
      let(:step_instructions) do
        {
          flags:
            [
              {
                type: 'publish',
                status: 'enable',
                project: 'home:Iggy',
                repository: 'openSUSE_Tumbleweed',
                architecture: 'x86_64'
              }
            ]
        }
      end

      before do
        target_project.add_flag('publish', 'disable', 'openSUSE_Tumbleweed', 'x86_64')
        target_project.save!
      end

      it 'does not raise an error and updates the status' do
        expect { subject.call }.not_to(change(Flag, :count))
        expect(Flag.all).to match_array([
                                          have_attributes(status: 'enable', repo: 'openSUSE_Tumbleweed', project_id: target_project.id, package_id: nil, flag: 'publish')
                                        ])
      end
    end
  end

  describe '#validate_flags' do
    let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }
    let(:scm_webhook) { SCMWebhook.new(payload: payload) }

    subject do
      described_class.new(step_instructions: step_instructions,
                          scm_webhook: scm_webhook,
                          token: token)
    end

    context 'when a flag is missing a key' do
      let(:step_instructions) do
        {
          flags:
            [
              {
                type: 'lock',
                status: 'disable'
              }
            ]
        }
      end

      it 'gives an error for a missing project' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages.to_sentence).to include("set_flags step: All flags must have the 'type', 'status', and 'project' keys")
      end
    end

    context 'when at least one flag is missing a key' do
      let(:step_instructions) do
        {
          flags:
            [
              {
                type: 'lock',
                status: 'disable'
              },
              {
                type: 'lock',
                status: 'disable',
                project: 'openSUSE:Factory'
              }
            ]
        }
      end

      it 'gives an error for a missing project' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages.to_sentence).to include("set_flags step: All flags must have the 'type', 'status', and 'project' keys")
      end
    end
  end
end
