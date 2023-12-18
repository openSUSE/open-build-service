RSpec.describe Cloud::User::UploadJob, :vcr do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:job_id) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to validate_uniqueness_of(:job_id) }
  end
end
