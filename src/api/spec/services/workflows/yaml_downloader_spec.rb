require 'rails_helper'

RSpec.describe Workflows::YAMLDownloader, type: :service do
  let(:yaml_downloader) { described_class.new(payload) }
  let(:max_size) { Workflows::YAMLDownloader::MAX_FILE_SIZE }

  describe '#call' do
    before do
      allow(Down).to receive(:download)
      yaml_downloader.call
    end

    context 'github' do
      let(:payload) { { scm: 'github', target_branch: 'master', repository_full_name: 'openSUSE/obs-server' } }
      let(:url) { "https://raw.githubusercontent.com/#{payload[:repository_full_name]}/#{payload[:target_branch]}/.obs/workflows.yml" }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end

    context 'gitlab' do
      let(:payload) { { scm: 'gitlab', target_branch: 'master', path_with_namespace: 'openSUSE/obs-server' } }
      let(:url) { "https://gitlab.com/#{payload[:path_with_namespace]}/-/raw/#{payload[:target_branch]}/.obs/workflows.yml" }

      it { expect(Down).to have_received(:download).with(url, max_size: max_size) }
    end
  end
end
