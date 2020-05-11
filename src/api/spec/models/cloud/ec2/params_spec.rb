require 'rails_helper'

RSpec.describe Cloud::Ec2::Params, type: :model, vcr: true do
  describe 'validations' do
    it { is_expected.to validate_presence_of :region }
    it { is_expected.to validate_presence_of :ami_name }
    it { is_expected.to allow_value('foo.raw.xz').for(:ami_name) }
    it { is_expected.not_to allow_value('lorem ipsum').for(:ami_name) }
    it { is_expected.to allow_value('us-east-1').for(:region) }
    it { is_expected.not_to allow_value('nuernberg-soutside').for(:region) }
    it { is_expected.to allow_value('subnet-23sdfg54').for(:vpc_subnet_id) }
    it { is_expected.not_to allow_value('subnet-2$sdfg54').for(:vpc_subnet_id) }
  end

  describe '.build' do
    it 'ignores not necessary values' do
      expect(Cloud::Ec2::Params.build(not: :necessary, region: 'us-east-1').region).to eq('us-east-1')
    end
  end
end
