require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::DistributionStrategyFactory do
  let(:project) { create(:project, name: 'openSUSE:Factory') }
  let(:distribution) { ObsFactory::Distribution.new(project) }
  let(:strategy) { distribution.strategy }
  let(:staging_project) { ObsFactory::StagingProject.new(project: staging_project_a, distribution: distribution) }

  describe 'openqa_version' do
    it { expect(strategy.openqa_version).to eq('Tumbleweed') }
  end

  describe 'openqa_group' do
    it { expect(strategy.openqa_group).to eq('openSUSE Tumbleweed') }
  end

  describe 'root_project_name' do
    it { expect(strategy.root_project_name).to eq('openSUSE:Factory') }
  end

  describe 'test_dvd_prefix' do
    it { expect(strategy.test_dvd_prefix).to eq('Test-DVD') }
  end

  describe 'totest_version_file' do
    it { expect(strategy.totest_version_file).to eq('images/local/000product:openSUSE-cd-mini-x86_64') }
  end

  describe 'arch' do
    it { expect(strategy.arch).to eq('x86_64') }
  end

  describe 'url_suffix' do
    it { expect(strategy.url_suffix).to eq('tumbleweed/iso') }
  end

  describe 'rings' do
    it { expect(strategy.rings).to eq(['Bootstrap', 'MinimalX']) }
  end

  describe 'repo_url' do
    it { expect(strategy.repo_url).to eq('http://download.opensuse.org/tumbleweed/repo/oss/media.1/media') }
  end

  describe 'published_arch' do
    it { expect(strategy.published_arch).to eq('i586') }
  end

  describe 'openqa_iso_prefix' do
    it { expect(strategy.openqa_iso_prefix).to eq('openSUSE-Staging') }
  end

  describe 'staging_manager' do
    it { expect(strategy.staging_manager).to eq('factory-staging') }
  end

  describe 'openqa_iso' do
    let(:staging_project_a) { create(:project, name: 'openSUSE:Factory:Staging:A') }
    let(:build_result) do
      {
        'result' => Xmlhash::XMLHash.new(
          'project' => 'openSUSE:Factory:Staging:A',
          'repository' => 'images',
          'arch' => 'x86_64',
          'code' => 'building',
          'state' => 'building',
          'binarylist' =>  Xmlhash::XMLHash.new(
            'package' => 'Test-DVD-x86_64',
            'binary' =>  Xmlhash::XMLHash.new(
              'filename' => 'Test-Build1036.1-Media.iso',
              'size' => '878993408',
              'mtime' => '1528339590'
            )
          )
        )
      }
    end

    before do
      allow(Buildresult).to receive(:find_hashed).and_return(Xmlhash::XMLHash.new(build_result))
    end

    it { expect(strategy.openqa_iso(staging_project)).to eq('openSUSE-Staging:A-Staging-DVD-x86_64-Build1036.1-Media.iso') }
  end

  describe '#published_version' do
    let(:file) { StringIO.new('openSUSE-20180604-i586-Build') }

    before do
      allow_any_instance_of(ObsFactory::DistributionStrategyFactory).to receive(:open).and_return(file)
    end

    it { expect(strategy.published_version).to eq('20180604') }
  end

  describe 'openqa_filter' do
    let(:staging_project_a) { create(:project, name: 'openSUSE:Factory:Staging:A') }

    it { expect(strategy.openqa_filter(staging_project)).to eq('match=Staging:A') }
  end

  describe '#totest_version' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{project}:ToTest/images/local/000product:openSUSE-cd-mini-x86_64" }
    let(:backend_response) do
      %(<binarylist>
          <binary filename="_channel" size="21" mtime="1530626778"/>
          <binary filename="_statistics" size="233" mtime="1530626778"/>
          <binary filename="openSUSE-Tumbleweed-NET-x86_64-Snapshot20180702-Media.iso" size="126877696" mtime="1530626781"/>
          <binary filename="openSUSE-Tumbleweed-NET-x86_64-Snapshot20180702-Media.iso.sha256" size="654" mtime="1530643927"/>
        </binarylist>)
    end

    before do
      stub_request(:get, backend_url).and_return(body: backend_response)
    end

    it { expect(strategy.totest_version).to eq('20180702') }
  end
end
