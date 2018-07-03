require 'rails_helper'

RSpec.describe ObsFactory::DistributionStrategyFactoryPPC do
  let(:project) { create(:project, name: 'openSUSE:Factory:PowerPC') }
  let(:distribution) { ObsFactory::Distribution.new(project) }
  let(:strategy) { distribution.strategy }

  describe 'root_project_name' do
    it { expect(strategy.root_project_name).to eq('openSUSE:Factory') }
  end

  describe 'totest_version_file' do
    it { expect(strategy.totest_version_file).to eq('images/local/000product:openSUSE-cd-mini-ppc64le') }
  end

  describe 'arch' do
    it { expect(strategy.arch).to eq('ppc64le') }
  end

  describe 'openqa_group' do
    it { expect(strategy.openqa_group).to eq('openSUSE Tumbleweed PowerPC') }
  end

  describe 'url_suffix' do
    it { expect(strategy.url_suffix).to eq('ports/ppc/factory') }
  end

  describe 'repo_url' do
    it { expect(strategy.repo_url).to eq('http://download.opensuse.org/ports/ppc/factory/repo/oss/media.1/build') }
  end

  describe 'published_arch' do
    it { expect(strategy.published_arch).to eq('ppc64le') }
  end
end
