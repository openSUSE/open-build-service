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

        let(:request_payload) { file_fixture('request_payload_github_synchronize.json').read }

        let(:octokit_client) { instance_double(Octokit::Client) }

        it 'downloads the workflow file' do
          expect(octokit_client).to have_received(:content)
        end
      end

      context 'gitlab' do
        let(:gitlab_client) { instance_spy(Gitlab::Client, file_contents: true) }
        let(:scm_vendor) { 'gitlab' }
        let(:hook_event) { 'Push Hook' }

        let(:request_payload) { file_fixture('request_payload_gitlab_push.json').read }

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
          let(:request_payload) { file_fixture('request_payload_gitea_tag_push.json').read }

          let(:url) { "https://gitea.opensuse.org/#{workflow_run.target_repository_full_name}/raw/tag/#{workflow_run.tag_name}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end

        context 'for a push event' do
          let(:scm_vendor) { 'gitea' }
          let(:hook_event) { 'push' }
          let(:request_payload) { file_fixture('request_payload_gitea_push.json').read }

          let(:url) { "https://gitea.opensuse.org/#{workflow_run.target_repository_full_name}/raw/branch/#{workflow_run.target_branch}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end

        context 'for a pull request event' do
          let(:scm_vendor) { 'gitea' }
          let(:hook_event) { 'pull_request' }
          let(:request_payload) { file_fixture('request_payload_gitea_pull_request_opened.json').read }

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

      let(:request_payload) { file_fixture('request_payload_gitlab_push.json').read }

      let(:url) { 'https://example.com/subdir/config_file.yml' }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end

    context 'given workflow_configuration_path' do
      let(:gitlab_client) { instance_spy(Gitlab::Client, file_contents: true) }
      let(:scm_vendor) { 'gitlab' }
      let(:hook_event) { 'Push Hook' }

      let(:request_payload) { file_fixture('request_payload_gitlab_push.json').read }

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

      let(:request_payload) { file_fixture('request_payload_gitlab_push.json').read }
      let(:url) { 'https://example.com/subdir/config_file.yml' }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end
  end
end
