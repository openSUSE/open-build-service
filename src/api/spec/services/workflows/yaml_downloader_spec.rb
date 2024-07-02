RSpec.describe Workflows::YAMLDownloader, type: :service do
  let(:workflow_token) { build(:workflow_token) }
  let(:yaml_downloader) { described_class.new(workflow_run, token: workflow_token) }
  let(:max_size) { Workflows::YAMLDownloader::MAX_FILE_SIZE }
  let(:workflow_run) do
    create(:workflow_run, scm_vendor: scm_vendor, hook_event: hook_event, request_payload: request_payload)
  end

  describe '#call' do
    before do
      allow(Down).to receive(:download)
    end

    context 'with default path' do
      context 'github' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:content).and_return({ content: Base64.encode64('Test content') })
          yaml_downloader.call
        end

        let(:scm_vendor) { 'github' }
        let(:hook_event) { 'pull_request' }

        let(:request_payload) do
          {
            action: 'synchronize',
            number: 1,
            pull_request: {
              html_url: 'http://github.com/something',
              base: {
                ref: 'master',
                repo: {
                  full_name: 'rubhanazeem/hello_world'
                }
              },
              head: {
                sha: '5d175d7f4c58d06907bba188fe9a4c8b6bd723da'
              }
            },
            repository: {
              name: 'hello_world',
              html_url: 'https://github.com',
              owner: {
                login: 'rubhanazeem'
              }
            }
          }.to_json
        end

        let(:octokit_client) { instance_double(Octokit::Client) }

        it 'downloads the workflow file' do
          expect(octokit_client).to have_received(:content)
        end
      end

      context 'gitlab' do
        let(:gitlab_client) { instance_spy(Gitlab::Client, file_contents: true) }
        let(:scm_vendor) { 'gitlab' }
        let(:hook_event) { 'Push Hook' }

        let(:request_payload) do
          {
            object_kind: 'push',
            after: 'd6568a7e5137e2c09bbb613d83c94fc68601ff93',
            ref: 'refs/heads/master',
            project_id: 7_836_486,
            project: {
              http_url: 'https://gitlab.com'
            }
          }.to_json
        end

        before do
          allow(Gitlab).to receive(:client).and_return(gitlab_client)
          yaml_downloader.call
        end

        it 'downloads the workflow file' do
          expect(gitlab_client).to have_received(:file_contents)
        end
      end

      context 'gitea' do
        before do
          yaml_downloader.call
        end

        context 'for a tag push event' do
          let(:scm_vendor) { 'gitea' }
          let(:hook_event) { 'push' }
          let(:request_payload) do
            {
              ref: 'refs/tags/3.0',
              after: '456',
              repository: {
                full_name: 'iggy/target_repo',
                clone_url: 'https://gitea.opensuse.org'
              }
            }.to_json
          end

          let(:url) { "https://gitea.opensuse.org/#{workflow_run.target_repository_full_name}/raw/tag/#{workflow_run.tag_name}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end

        context 'for a push event' do
          let(:scm_vendor) { 'gitea' }
          let(:hook_event) { 'push' }
          let(:request_payload) do
            {
              ref: 'refs/heads/main',
              after: '456',
              repository: {
                full_name: 'iggy/target_repo',
                clone_url: 'https://gitea.opensuse.org'
              }
            }.to_json
          end

          let(:url) { "https://gitea.opensuse.org/#{workflow_run.target_repository_full_name}/raw/branch/#{workflow_run.target_branch}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end

        context 'for a pull request event' do
          let(:scm_vendor) { 'gitea' }
          let(:hook_event) { 'pull_request' }
          let(:request_payload) do
            {
              action: 'opened',
              number: 1,
              pull_request: {
                base: {
                  ref: 'main',
                  repo: {
                    full_name: 'iggy/target_repo'
                  }
                }
              },
              repository: {
                full_name: 'iggy/target_repo',
                clone_url: 'https://gitea.opensuse.org'
              }
            }.to_json
          end

          let(:url) { "https://gitea.opensuse.org/#{workflow_run.target_repository_full_name}/raw/branch/#{workflow_run.target_branch}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end
      end
    end

    context 'given workflow_configuration_url' do
      before do
        workflow_token.workflow_configuration_url = 'https://example.com/subdir/config_file.yml'
        yaml_downloader.call
      end

      let(:scm_vendor) { 'gitlab' }
      let(:hook_event) { 'Push Hook' }

      let(:request_payload) do
        {
          object_kind: 'push',
          after: 'd6568a7e5137e2c09bbb613d83c94fc68601ff93',
          ref: 'refs/heads/master',
          project_id: 7_836_486,
          project: {
            http_url: 'https://gitlab.com'
          }
        }.to_json
      end

      let(:url) { 'https://example.com/subdir/config_file.yml' }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end

    context 'given workflow_configuration_path' do
      let(:gitlab_client) { instance_spy(Gitlab::Client, file_contents: true) }
      let(:scm_vendor) { 'gitlab' }
      let(:hook_event) { 'Push Hook' }

      let(:request_payload) do
        {
          object_kind: 'push',
          after: 'd6568a7e5137e2c09bbb613d83c94fc68601ff93',
          ref: 'refs/heads/master',
          project_id: 7_836_486,
          project: {
            http_url: 'https://gitlab.com'
          }
        }.to_json
      end

      before do
        allow(Gitlab).to receive(:client).and_return(gitlab_client)
        workflow_token.workflow_configuration_path = 'subdir/config_file.yml'
        yaml_downloader.call
      end

      it { expect(gitlab_client).to have_received(:file_contents) }
    end

    context 'given both workflow_configuration_path and workflow_configuration_url' do
      before do
        workflow_token.workflow_configuration_url = 'https://example.com/subdir/config_file.yml'
        workflow_token.workflow_configuration_path = 'subdir/config_file.yml'
        yaml_downloader.call
      end

      let(:scm_vendor) { 'gitlab' }
      let(:hook_event) { 'Push Hook' }

      let(:request_payload) do
        {
          object_kind: 'push',
          after: 'd6568a7e5137e2c09bbb613d83c94fc68601ff93',
          ref: 'refs/heads/master',
          project_id: 7_836_486,
          project: {
            http_url: 'https://gitlab.com'
          }
        }.to_json
      end
      let(:url) { 'https://example.com/subdir/config_file.yml' }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end
  end
end
