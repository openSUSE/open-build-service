require 'rails_helper'

RSpec.describe ObsFactory::DistributionStrategySLE15 do
  let(:project) { create(:project, name: 'SUSE:SLE-15:GA') }
  let(:distribution) { ObsFactory::Distribution.new(project) }
  let(:strategy) { distribution.strategy }

  describe '#sp_version' do
    it 'returns the correct service pack version' do
      expect(strategy.sp_version('SUSE:SLE-15:GA')).to be_nil
      expect(strategy.sp_version('SUSE:SLE-15-SP4:GA')).to eq('SP4')
    end
  end

  describe 'openqa_version' do
    it { expect(strategy.openqa_version).to eq('SLES 15') }
  end

  describe 'test_dvd_prefix' do
    it { expect(strategy.test_dvd_prefix).to eq('000product:SLES-cd-DVD') }
  end

  describe 'repo_url' do
    it { expect(strategy.repo_url).to eq('http://download.opensuse.org/distribution/13.2/repo/oss/media.1/build') }
  end

  describe 'staging_manager' do
    it { expect(strategy.staging_manager).to eq('sle-staging-managers') }
  end

  describe 'openqa_iso' do
    let(:staging_a) { create(:project, name: 'SUSE:SLE-15:GA:Staging:A') }
    let(:staging_project) { ObsFactory::StagingProject.new(project: staging_a, distribution: distribution) }
    let(:build_result) do
      {
        'result' => Xmlhash::XMLHash.new(
          'project' => 'SUSE:SLE-15:GA:Staging:A',
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

    it { expect(strategy.openqa_iso(staging_project)).to eq('SLE-15-Staging:A-Installer-DVD-x86_64-BuildA.1036.1-Media.iso') }
  end
end
