require 'rails_helper'

RSpec.describe Workflow::Step do
  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, user: user) }
  let(:step) do
    Class.new(described_class) do
      def target_project_base_name
        'OBS:Server:Unstable'
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
      step.new(step_instructions: step_instructions,
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

        it { is_expected.to eq('OBS:Server:Unstable:openSUSE:repo123:PR-1') }
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
  end
end
