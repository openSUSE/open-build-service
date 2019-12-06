require 'rails_helper'

RSpec.describe Cloud::User::UploadJob, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:job_id) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_uniqueness_of(:job_id) }
  end
end
