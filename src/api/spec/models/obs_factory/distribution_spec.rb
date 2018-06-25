require 'rails_helper'

RSpec.describe ObsFactory::Distribution do
  describe '::new' do
    def strategy_for(name)
      ObsFactory::Distribution.new(create(:project, name: name)).strategy
    end

    it { expect(strategy_for('openSUSE:Factory')).to         be_kind_of ObsFactory::DistributionStrategyFactory }
    it { expect(strategy_for('openSUSE:Factory:PowerPC')).to be_kind_of ObsFactory::DistributionStrategyFactoryPPC }
    it { expect(strategy_for('openSUSE:42.3')).to            be_kind_of ObsFactory::DistributionStrategyOpenSUSE }
    it { expect(strategy_for('SUSE:SLE-12-SP1:GA')).to       be_kind_of ObsFactory::DistributionStrategySLE12SP1 }
    it { expect(strategy_for('SUSE:SLE-15:GA')).to           be_kind_of ObsFactory::DistributionStrategySLE15 }
    it { expect(strategy_for('SUSE:SLE-15-SP1:GA')).to       be_kind_of ObsFactory::DistributionStrategySLE15 }
    it { expect(strategy_for('SUSE:SLE-12-SP3:Update:Products:CASP20')).to be_kind_of ObsFactory::DistributionStrategyCasp }
  end
end
