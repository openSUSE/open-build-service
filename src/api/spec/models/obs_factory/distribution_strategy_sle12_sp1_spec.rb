require 'rails_helper'

RSpec.describe ObsFactory::DistributionStrategySLE12SP1 do
  let(:project) { create(:project, name: 'SUSE:SLE-12-SP4:GA') }
  let(:project_staging_a) { create(:project, name: 'SUSE:SLE-12-SP4:GA:Staging:A') }
  let(:distribution) { ObsFactory::Distribution.new(project) }
  let(:staging_project) { ObsFactory::StagingProject.new(project: project_staging_a, distribution: distribution) }

  subject { distribution.strategy }

  describe '#sp_version' do
    it { expect(subject.sp_version).to eq('SP4') }
  end

  describe '#openqa_version' do
    it { expect(subject.openqa_version).to eq('SLES 12 SP4') }
  end

  describe '#openqa_iso' do
    let(:iso_filename) { 'Test-Server-DVD-x86_64-Build19.2-Media.iso' }
    before do
      allow_any_instance_of(ObsFactory::DistributionStrategySLE12SP1).to receive(:project_iso).and_return(iso_filename)
    end

    it { expect(subject.openqa_iso(staging_project)).to eq('SLE12-SP4-Staging:A-Test-Server-DVD-x86_64-BuildA.19.2-Media.iso') }

    context 'without project iso' do
      let(:iso_filename) { nil }

      it { expect(subject.openqa_iso(staging_project)).to be_nil }
    end
  end
end
