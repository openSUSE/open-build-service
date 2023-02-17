require 'rails_helper'

RSpec.describe TriggerControllerService::SCMExtractor do
  describe '#call' do
    subject(:scm_webhook) do
      described_class.new(scm, event, payload).call
    end

    context 'when the SCM is unsupported' do
      let(:scm) { 'phabricator' }
      let(:event) { 'something' }
      let(:payload) { {} }

      it { expect(scm_webhook).to be_nil }
    end

    context 'when the SCM is GitHub' do
      let(:scm) { 'github' }

      context 'for a pull request event' do
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

        it 'returns an instance of SCMWebhook with the extracted data from the GitHub payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end

      context 'with a push event for a commit' do
        let(:event) { 'push' }
        let(:payload) do
          {
            ref: 'refs/heads/main/fix-bug',
            after: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            repository: {
              full_name: 'iggy/repo123'
            },
            sender: {
              url: 'https://api.github.com'
            },
            base_ref: nil,
            deleted: false
          }
        end
        let(:expected_hash) do
          {
            scm: 'github',
            event: 'push',
            api_endpoint: 'https://api.github.com',
            commit_sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            target_branch: 'main/fix-bug',
            source_repository_full_name: 'iggy/repo123',
            target_repository_full_name: 'iggy/repo123',
            ref: 'refs/heads/main/fix-bug',
            deleted: false
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitHub payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end

      context 'with a push event for a tag' do
        let(:event) { 'push' }
        let(:payload) do
          {
            ref: 'refs/tags/release_abc',
            after: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            repository: {
              full_name: 'iggy/repo123'
            },
            sender: {
              url: 'https://api.github.com'
            },
            base_ref: 'refs/heads/main',
            head_commit: {
              id: '8823eec73e46f29082cd343077ee3e97d8da0ec3'
            },
            deleted: false
          }
        end
        let(:expected_hash) do
          {
            scm: 'github',
            event: 'push',
            api_endpoint: 'https://api.github.com',
            commit_sha: '8823eec73e46f29082cd343077ee3e97d8da0ec3',
            target_branch: '8823eec73e46f29082cd343077ee3e97d8da0ec3',
            source_repository_full_name: 'iggy/repo123',
            target_repository_full_name: 'iggy/repo123',
            ref: 'refs/tags/release_abc',
            tag_name: 'release_abc',
            deleted: false
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitHub payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end
    end

    context 'when the SCM is GitLab' do
      let(:scm) { 'gitlab' }

      context 'for a merge request event' do
        let(:event) { 'Merge Request Hook' }
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
            event: 'Merge Request Hook',
            api_endpoint: 'https://gitlab.com'
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitLab payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end

      context 'with a push event for a commit' do
        let(:event) { 'Push Hook' }
        let(:payload) do
          {
            object_kind: 'push',
            ref: 'refs/heads/main/fix-bug',
            after: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            project_id: 3,
            project: {
              http_url: 'https://gitlab.com/eduardoj2/test.git',
              path_with_namespace: 'eduardoj2/test'
            }
          }
        end
        let(:expected_hash) do
          {
            scm: 'gitlab',
            object_kind: 'push',
            http_url: 'https://gitlab.com/eduardoj2/test.git',
            commit_sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            target_branch: 'main/fix-bug',
            project_id: 3,
            path_with_namespace: 'eduardoj2/test',
            event: 'Push Hook',
            api_endpoint: 'https://gitlab.com',
            ref: 'refs/heads/main/fix-bug'
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitLab payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end

      context 'with a push event for a tag' do
        let(:event) { 'Tag Push Hook' }
        let(:payload) do
          {
            object_kind: 'tag_push',
            after: '82b3d5ae55f7080f1e6022629cdb57bfae7cccc7',
            ref: 'refs/tags/release_abc',
            project: {
              http_url: 'https://gitlab.com/jane/doe.git',
              path_with_namespace: 'jane/doe'
            }
          }
        end
        let(:expected_hash) do
          {
            scm: 'gitlab',
            object_kind: 'tag_push',
            http_url: 'https://gitlab.com/jane/doe.git',
            event: 'Tag Push Hook',
            api_endpoint: 'https://gitlab.com',
            tag_name: 'release_abc',
            target_branch: '82b3d5ae55f7080f1e6022629cdb57bfae7cccc7',
            path_with_namespace: 'jane/doe',
            ref: 'refs/tags/release_abc',
            commit_sha: '82b3d5ae55f7080f1e6022629cdb57bfae7cccc7'
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitLab payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end
    end

    context 'when some of the payload keys are missing' do
      let(:scm) { 'gitlab' }
      let(:event) { 'Merge Request Hook' }
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
          event: 'Merge Request Hook',
          api_endpoint: 'https://gitlab.com',
          http_url: 'https://gitlab.com/eduardoj2/test.git'
        }
      end

      it 'returns an instance of SCMWebhook with the extracted data' do
        expect(scm_webhook).to be_instance_of(SCMWebhook)
        expect(scm_webhook.payload).to eq(expected_hash)
      end
    end

    context 'when the SCM is Gitea' do
      let(:scm) { 'gitea' }

      context 'for a pull request event' do
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
            repository: {
              clone_url: 'https://gitea.opensuse.org/krauselukas/test.git'
            },
            number: 4
          }
        end
        let(:expected_hash) do
          {
            scm: 'gitea',
            commit_sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            pr_number: 4,
            source_branch: 'add-changes',
            target_branch: 'main',
            action: 'opened',
            source_repository_full_name: 'iggy/source_repo',
            target_repository_full_name: 'iggy/target_repo',
            event: 'pull_request',
            api_endpoint: 'https://gitea.opensuse.org',
            http_url: 'https://gitea.opensuse.org/krauselukas/test.git'
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the Gitea payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end

      context 'with a push event for a commit' do
        let(:event) { 'push' }
        let(:payload) do
          {
            ref: 'refs/heads/main/fix-bug',
            after: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            repository: {
              full_name: 'iggy/repo123',
              clone_url: 'https://gitea.opensuse.org/krauselukas/test.git'
            },
            base_ref: nil
          }
        end
        let(:expected_hash) do
          {
            scm: 'gitea',
            event: 'push',
            api_endpoint: 'https://gitea.opensuse.org',
            commit_sha: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            target_branch: 'main/fix-bug',
            source_repository_full_name: 'iggy/repo123',
            target_repository_full_name: 'iggy/repo123',
            ref: 'refs/heads/main/fix-bug',
            http_url: 'https://gitea.opensuse.org/krauselukas/test.git'
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitHub payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end

      context 'with a push event for a tag' do
        let(:event) { 'push' }
        let(:payload) do
          {
            ref: 'refs/tags/release_abc',
            after: '9e0ea1fd99c9000cbb8b8c9d28763d0ddace0b65',
            repository: {
              full_name: 'iggy/repo123',
              clone_url: 'https://gitea.opensuse.org/krauselukas/test.git'
            },
            base_ref: 'refs/heads/main',
            head_commit: {
              id: '8823eec73e46f29082cd343077ee3e97d8da0ec3'
            }
          }
        end
        let(:expected_hash) do
          {
            scm: 'gitea',
            event: 'push',
            api_endpoint: 'https://gitea.opensuse.org',
            commit_sha: '8823eec73e46f29082cd343077ee3e97d8da0ec3',
            target_branch: '8823eec73e46f29082cd343077ee3e97d8da0ec3',
            source_repository_full_name: 'iggy/repo123',
            target_repository_full_name: 'iggy/repo123',
            ref: 'refs/tags/release_abc',
            tag_name: 'release_abc',
            http_url: 'https://gitea.opensuse.org/krauselukas/test.git'
          }
        end

        it 'returns an instance of SCMWebhook with the extracted data from the GitHub payload' do
          expect(scm_webhook).to be_instance_of(SCMWebhook)
          expect(scm_webhook.payload).to eq(expected_hash)
        end
      end
    end
  end
end
