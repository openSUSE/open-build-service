require 'rails_helper'

RSpec.describe Workflows::YAMLDownloader, type: :service do
  let(:workflow_token) { build(:workflow_token) }
  let(:yaml_downloader) { described_class.new(payload, token: workflow_token) }
  let(:max_size) { Workflows::YAMLDownloader::MAX_FILE_SIZE }

  describe '#call' do
    before do
      allow(Down).to receive(:download)
    end

    context 'with default path' do
      context 'github' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(octokit_client)
          allow(octokit_client).to receive(:content).and_return({ download_url: url })
          yaml_downloader.call
        end

        let(:payload) do
          {
            scm: 'github',
            commit_sha: '5d175d7f4c58d06907bba188fe9a4c8b6bd723da',
            pr_number: 1,
            source_branch: 'test-pr',
            target_branch: 'master',
            action: 'synchronize',
            source_repository_full_name: 'rubhanazeem/hello_world',
            target_repository_full_name: 'rubhanazeem/hello_world',
            event: 'pull_request',
            api_endpoint: 'https://api.github.com'
          }
        end
        let(:octokit_client) { instance_double(Octokit::Client) }
        let(:url) { "https://raw.githubusercontent.com/#{payload[:target_repository_full_name]}/#{payload[:target_branch]}/.obs/workflows.yml" }

        it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
      end

      context 'gitlab' do
        before do
          yaml_downloader.call
        end

        let(:payload) { { scm: 'gitlab', target_branch: 'master', path_with_namespace: 'openSUSE/obs-server', api_endpoint: 'https://gitlab.com' } }
        let(:url) { "https://gitlab.com/#{payload[:path_with_namespace]}/-/raw/#{payload[:target_branch]}/.obs/workflows.yml" }

        it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
      end

      context 'gitea' do
        before do
          yaml_downloader.call
        end

        context 'for a tag push event' do
          let(:payload) do
            {
              scm: 'gitea',
              target_repository_full_name: 'iggy/target_repo',
              api_endpoint: 'https://gitea.opensuse.org',
              tag_name: '3.0'
            }
          end
          let(:url) { "https://gitea.opensuse.org/#{payload[:target_repository_full_name]}/raw/tag/#{payload[:tag_name]}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end

        context 'for a push or pull request event' do
          let(:payload) do
            {
              scm: 'gitea',
              target_branch: 'main',
              target_repository_full_name: 'iggy/target_repo',
              api_endpoint: 'https://gitea.opensuse.org'
            }
          end
          let(:url) { "https://gitea.opensuse.org/#{payload[:target_repository_full_name]}/raw/branch/#{payload[:target_branch]}/.obs/workflows.yml" }

          it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
        end
      end
    end

    context 'given workflow_configuration_url' do
      before do
        workflow_token.workflow_configuration_url = 'https://example.com/subdir/config_file.yml'
        yaml_downloader.call
      end

      let(:payload) { { scm: 'gitlab', target_branch: 'master', path_with_namespace: 'openSUSE/obs-server', api_endpoint: 'https://gitlab.com' } }
      let(:url) { 'https://example.com/subdir/config_file.yml' }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end

    context 'given workflow_configuration_path' do
      before do
        workflow_token.workflow_configuration_path = 'subdir/config_file.yml'
        yaml_downloader.call
      end

      let(:payload) { { scm: 'gitlab', target_branch: 'master', path_with_namespace: 'openSUSE/obs-server', api_endpoint: 'https://gitlab.com' } }
      let(:url) { "https://gitlab.com/#{payload[:path_with_namespace]}/-/raw/#{payload[:target_branch]}/subdir/config_file.yml" }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end

    context 'given both workflow_configuration_path and workflow_configuration_url' do
      before do
        workflow_token.workflow_configuration_url = 'https://example.com/subdir/config_file.yml'
        workflow_token.workflow_configuration_path = 'subdir/config_file.yml'
        yaml_downloader.call
      end

      let(:payload) { { scm: 'gitlab', target_branch: 'master', path_with_namespace: 'openSUSE/obs-server', api_endpoint: 'https://gitlab.com' } }
      let(:url) { 'https://example.com/subdir/config_file.yml' }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end
  end
end
