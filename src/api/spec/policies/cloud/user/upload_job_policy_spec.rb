RSpec.describe Cloud::User::UploadJobPolicy do
  subject { described_class }

  let(:uploader) { create(:confirmed_user) }
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }
  let(:staff_user) { create(:staff_user) }
  let(:upload_job) { create(:upload_job, user: uploader) }

  shared_examples_for 'a upload job policy' do
    it 'allows admin users to see any log' do
      expect(subject).to permit(admin_user, upload_job)
    end

    it 'allows staff users to see any log' do
      expect(subject).to permit(staff_user, upload_job)
    end

    it 'allows users to see their own logs' do
      expect(subject).to permit(uploader, upload_job)
    end

    it 'does not allow users to see logs of other user' do
      expect(subject).not_to permit(user, upload_job)
    end
  end

  permissions :show? do
    it_behaves_like 'a upload job policy'
  end

  permissions :destroy? do
    it_behaves_like 'a upload job policy'
  end
end
