require 'rails_helper'

RSpec.describe TriggerControllerService::ScmExtractor do
  describe '#call' do
    subject(:scm_webhook) do
      described_class.new(scm, event, payload).call
    end

    context 'when the scm is github' do
      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              repo: {
                full_name: 'iggy/source_repo'
              },
              ref: 'add-changes',
              sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65'
            },
            base: {
              repo: {
                full_name: 'iggy/target_repo'
              },
              ref: 'main'
            }
          },
          project: {
            http_url: 'https://gitlab.com/eduardoj2/test.git',
            id: 26_212_710,
            path_with_namespace: 'eduardoj2/test'
          },
          number: 4,
          sender: {
            url: 'https://api.github.com'
          }
        }
      end
      let(:expected_hash) do
        {
          scm: 'github',
          commit_sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
          pr_number: 4,
          source_branch: 'add-changes',
          target_branch: 'main',
          action: 'opened',
          source_repository_full_name: 'iggy/source_repo',
          target_repository_full_name: 'iggy/target_repo',
          event: 'pull_request',
          api_endpoint: 'https://api.github.com'
        }
      end

      it 'returns an instance of ScmWebhook with the extracted data from the GitHub payload' do
        expect(scm_webhook).to be_instance_of(ScmWebhook)
        expect(scm_webhook.payload).to include(expected_hash)
      end
    end

    context 'when the scm is gitlab' do
      let(:scm) { 'gitlab' }
      let(:event) { 'merge_request' }
      let(:payload) do
        {
          object_kind: 'merge_request',
          project: {
            http_url: 'https://gitlab.com/eduardoj2/test.git',
            path_with_namespace: 'eduardoj2/test'
          },
          object_attributes: {
            last_commit: {
              id: '4b486afefa44177f23b4388d2147ae42407e7f64'
            },
            iid: 3,
            source_project_id: 26_212_710,
            source_branch: 'nuevo',
            target_branch: 'master',
            action: 'open'
          },
          action: 'opened'
        }
      end
      let(:expected_hash) do
        {
          scm: 'gitlab',
          object_kind: 'merge_request',
          http_url: 'https://gitlab.com/eduardoj2/test.git',
          commit_sha: '4b486afefa44177f23b4388d2147ae42407e7f64',
          pr_number: 3,
          source_branch: 'nuevo',
          target_branch: 'master',
          action: 'open',
          project_id: 26_212_710,
          path_with_namespace: 'eduardoj2/test',
          event: 'merge_request'
        }
      end

      it 'returns an instance of ScmWebhook with the extracted data from the GitLab payload' do
        expect(scm_webhook).to be_instance_of(ScmWebhook)
        expect(scm_webhook.payload).to include(expected_hash)
      end
    end

    context 'when the scm is neither github nor gitlab' do
      let(:scm) { 'phabricator' }
      let(:event) { 'dont care' }
      let(:payload) { {} }

      it 'returns nil' do
        expect(scm_webhook).to be_nil
      end
    end

    context 'when some of the payload keys are missing' do
      let(:scm) { 'gitlab' }
      let(:event) { 'merge_request' }
      let(:payload) do
        {
          project: {
            http_url: 'https://gitlab.com/eduardoj2/test.git'
          }
        }
      end
      let(:expected_hash) do
        {
          scm: 'gitlab',
          object_kind: nil,
          commit_sha: nil,
          pr_number: nil,
          source_branch: nil,
          target_branch: nil,
          action: nil,
          project_id: nil,
          path_with_namespace: nil,
          event: 'merge_request',
          api_endpoint: 'https://gitlab.com',
          http_url: 'https://gitlab.com/eduardoj2/test.git'
        }
      end

      it 'returns an instance of ScmWebhook with the extracted data' do
        expect(scm_webhook).to be_instance_of(ScmWebhook)
        expect(scm_webhook.payload).to include(expected_hash)
      end
    end
  end
end
