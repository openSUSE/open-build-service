require 'rails_helper'

RSpec.describe Workflows::YAMLDownloader, type: :service do
  let(:yaml_downloader) { described_class.new(payload, token: build(:workflow_token)) }
  let(:max_size) { Workflows::YAMLDownloader::MAX_FILE_SIZE }
  let(:github_payload) do
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

  describe '#call' do
    before do
      allow(Down).to receive(:download)
    end

    context 'github' do
      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_return({ download_url: url })
        yaml_downloader.call
      end

      let(:payload) { github_payload }
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
  end
end
