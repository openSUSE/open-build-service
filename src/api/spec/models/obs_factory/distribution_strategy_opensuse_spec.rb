require 'rails_helper'

RSpec.describe ObsFactory::DistributionStrategyOpenSUSE do
  let(:strategy) { ObsFactory::DistributionStrategyOpenSUSE.new(project: create(:project, name: 'openSUSE:Leap:42.3')) }

  describe '#openqa_version' do
    it 'returns the openqa version of a distribution' do
      expect(strategy.openqa_version).to eq('42')
    end
  end

  describe '#opensuse_version' do
    it 'returns the openqa version of a distribution' do
      expect(strategy.opensuse_version).to eq('Leap:42.3')
    end
  end

  describe '#opensuse_leap_version' do
    it 'returns the openqa version of a distribution' do
      expect(strategy.opensuse_leap_version).to eq('42.3')
    end
  end
end
