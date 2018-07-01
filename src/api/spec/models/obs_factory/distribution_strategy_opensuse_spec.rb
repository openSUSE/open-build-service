require 'rails_helper'

RSpec.describe ObsFactory::DistributionStrategyOpenSUSE do
  describe '#openqa_version' do
    let(:strategy) { ObsFactory::DistributionStrategyOpenSUSE.new(project: create(:project, name: 'openSUSE:Leap:42.3')) }

    it 'returns the openqa version of a distribution' do
      expect(strategy.openqa_version).to eq('42')
    end
  end
end
