require 'rails_helper'

RSpec.describe Cloud::Ec2::Configuration, type: :model, vcr: true do
  describe 'validations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_uniqueness_of(:external_id) }
    it { is_expected.to validate_uniqueness_of(:arn) }
    it { is_expected.to allow_value('arn:123:456/tom').for(:arn) }
    it { is_expected.not_to allow_value('123:456/tom').for(:arn) }
  end
end
