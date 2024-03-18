RSpec.describe Cloud::Ec2::Configuration, :vcr do
  describe 'validations' do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to validate_uniqueness_of(:external_id) }
    it { is_expected.to validate_uniqueness_of(:arn) }
    it { is_expected.to allow_value('arn:123:45.6/*/tom tom/test-role+=,.@-_').for(:arn) }
    it { is_expected.not_to allow_value('123:456/tom').for(:arn) }
  end

  describe 'upload_parameters' do
    subject { ec2_config.upload_parameters }

    let(:ec2_config) { create(:ec2_configuration) }

    it { expect(subject.keys.count).to be(3) }
    it { expect(subject['arn']).to eq(ec2_config.arn) }
    it { expect(subject['user_id']).to eq(ec2_config.user_id) }
    it { expect(subject['external_id']).to eq(ec2_config.external_id) }
  end
end
