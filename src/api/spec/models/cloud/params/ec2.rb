require 'rails_helper'

RSpec.describe Cloud::Params::Ec2, type: :model, vcr: true do
  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:virtualization_type).in_array(['hvm', 'pv']) }
    it { is_expected.to validate_presence_of :region }
    it { is_expected.to validate_presence_of :ami_name }
    it { is_expected.to allow_value('foo.raw.xz').for(:ami_name) }
    it { is_expected.not_to allow_value('lorem ipsum').for(:ami_name) }
    it { is_expected.to allow_value('us-east-1').for(:region) }
    it { is_expected.not_to allow_value('nuernberg-soutside').for(:region) }
  end

  describe '.build' do
    it 'ignores not necessary values' do
      expect(Cloud::Params::Ec2.build(not: :necessary, region: 'us-east-1').region).to eq('us-east-1')
    end
  end
end
