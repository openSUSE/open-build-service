require 'rails_helper'

RSpec.describe TriggerControllerService::ScmExtractor do
  subject do
    described_class.new(scm, event, payload)
  end

  describe '#allowed_event_and_action' do
    context 'when the scm is github' do
      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:payload) do
        {
          action: 'opened'
        }
      end

      it 'returns true' do
        expect(subject).to be_allowed_event_and_action
      end
    end

    context 'when the scm is gitlab' do
      let(:scm) { 'gitlab' }
      let(:event) { 'Merge Request Hook' }
      let(:payload) do
        {
          object_attributes: {
            action: 'open'
          }
        }
      end

      it 'returns true' do
        expect(subject).to be_allowed_event_and_action
      end
    end

    context 'when the scm is neither github nor gitlab' do
      let(:scm) { 'phabricator' }
      let(:event) { 'dont care' }
      let(:payload) { {} }

      it 'returns true' do
        expect(subject).not_to be_allowed_event_and_action
      end
    end
  end

  describe '#call' do
    context 'when the scm is github' do
      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:payload) do
        {
          action: 'opened',
          pull_request: {
            head: {
              repo: {
                full_name: 'danidoni/test_repo',
                html_url: 'https://github.com/openSUSE/open-build-service'
              },
              ref: 'add-changes',
              sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65'
            },
            base: {
              ref: 'main'
            }
          },
          number: 4
        }
      end
      let(:expected_hash) do
        {
          scm: 'github',
          repo_url: 'https://github.com/openSUSE/open-build-service',
          commit_sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
          pr_number: 4,
          source_branch: 'add-changes',
          target_branch: 'main',
          action: 'opened',
          repository_full_name: 'danidoni/test_repo',
          event: 'pull_request'
        }
      end

      it 'returns a hash with the extracted data from the github payload' do
        expect(subject.call).to include(expected_hash)
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
            id: 26_212_710,
            path_with_namespace: 'eduardoj2/test'
          },
          object_attributes: {
            last_commit: {
              id: '4b486afefa44177f23b4388d2147ae42407e7f64'
            },
            iid: 3,
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

      it 'returns a hash with the extracted data from the gitlab payload' do
        expect(subject.call).to include(expected_hash)
      end
    end

    context 'when the scm is neither github nor gitlab' do
      let(:scm) { 'phabricator' }
      let(:event) { 'dont care' }
      let(:payload) { {} }

      it 'returns true' do
        expect(subject.call).to be_nil
      end
    end

    context 'when some of the payload keys are missing' do
      let(:scm) { 'gitlab' }
      let(:event) { 'merge_request' }
      let(:payload) do
        {
        }
      end
      let(:expected_hash) do
        {
          scm: 'gitlab',
          object_kind: nil,
          http_url: nil,
          commit_sha: nil,
          pr_number: nil,
          source_branch: nil,
          target_branch: nil,
          action: nil,
          project_id: nil,
          path_with_namespace: nil,
          event: 'merge_request'
        }
      end

      it 'returns a hash with the corresponding values missing' do
        expect(subject.call).to include(expected_hash)
      end
    end
  end
end
