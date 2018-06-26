require 'rails_helper'

RSpec.describe ObsFactory::DistributionStrategySLE15 do
  let(:stategy) { ObsFactory::DistributionStrategySLE15.new(project: create(:project)) }

  describe '#sp_version' do
    it 'returns the correct service pack version' do
      expect(stategy.sp_version('SUSE:SLE-15:GA')).to be_nil
      expect(stategy.sp_version('SUSE:SLE-15-SP4:GA')).to eq('SP4')
    end
  end
end
